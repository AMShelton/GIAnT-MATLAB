function [skIm, P] = localizeSources_vIM(IM, vIM, params, doPlot)
%LOCALIZESOURCES_VIM Localize activity sources with bounded RAM usage.
%
% Inputs
%   IM     - H x W x T activity-channel registered movie.
%   vIM    - either:
%              []                         -> unit variance factor
%              numeric H x W x T          -> legacy in-memory variance
%              struct with fields
%                   .filename              -> alignment H5
%                   .dataset               -> usually /slap2/varFacDS
%   params - SILo parameters.
%
% RAM optimization
% ----------------
% The legacy implementation simultaneously materialized several H x W x T
% arrays (IM, varFacDS, smoothed variance, baseline, filtered activity, and
% local-max masks). For SLAP2 this can require many GB per worker.
%
% This implementation preserves the same source-localization operations but
% performs them in spatial tiles. Temporal filters still see the complete
% time series for every pixel, while each tile carries a halo large enough
% for the spatial Difference-of-Gaussians/local-maximum operations. The
% variance movie is read lazily from HDF5, so /slap2/varFacDS never needs to
% exist as a full MATLAB array.

if nargin < 4
    doPlot = false;
end

if ~isa(IM, 'single')
    IM = single(IM);
end

sz = size(IM);
if numel(sz) < 3
    sz(3) = 1;
end
H = sz(1); W = sz(2); nTimePoints = sz(3);

tau = params.tau_s .* params.alignHz;
params.tau_frames = tau;
sigma = params.sigma_px;
baselineWindow = ceil(params.baselineWindow_Glu_s .* params.alignHz);
denoiseWindow = ceil(params.denoiseWindow_s .* params.alignHz);
varSmoothWindow = ceil(denoiseWindow/2);

% Hidden performance setting. It intentionally need not appear in optionsGUI;
% users can still pass params.localizationTileSize explicitly if desired.
if ~isfield(params, 'localizationTileSize') || isempty(params.localizationTileSize)
    tileSize = 96;
else
    tileSize = max(16, round(params.localizationTileSize));
end

% Pixel inclusion is identical to the legacy implementation.
nanFrac = mean(isnan(IM), 3);
valid = nanFrac < params.nanThresh;
if ~any(valid, 'all')
    warning('Recording had no valid pixels; likely too much motion')
    P = [];
    skIm = nan(H,W,'single');
    return
end

% Resolve the variance source. For alignment H5 files written with the old
% full-frame chunk layout, transparently create a spatially chunked local
% cache once. This prevents every spatial tile from repeatedly reading every
% full-frame HDF5 chunk over network storage.
[varSource, cleanupObj] = prepareVarianceSource(vIM, [H W nTimePoints], tileSize, params); %#ok<NASGU>

% Find the first 500 frames containing data in globally valid pixels without
% constructing a full H x W x T logical mask.
frameHasData = false(1,nTimePoints);
for r0 = 1:tileSize:H
    r1 = min(H, r0+tileSize-1);
    for c0 = 1:tileSize:W
        c1 = min(W, c0+tileSize-1);
        validTile = valid(r0:r1,c0:c1);
        if ~any(validTile,'all')
            continue
        end
        raw = IM(r0:r1,c0:c1,:);
        raw2 = reshape(raw, [], nTimePoints);
        frameHasData = frameHasData | any(~isnan(raw2(validTile(:),:)),1);
        clear raw raw2
    end
end
firstValidFrames = find(frameHasData, 500, 'first');
if isempty(firstValidFrames)
    warning('Recording had no valid frames after pixel validity screening.')
    P = [];
    skIm = nan(H,W,'single');
    return
end

%% Estimate global variance model using a bounded calibration interval
% IMb at the first 500 valid frames depends on nearby future samples. Use a
% deliberately generous look-ahead so centered movmean/movmedian operations
% match a full-recording calculation at those calibration frames.
lookAhead = baselineWindow + varSmoothWindow + 4;
calEnd = min(nTimePoints, max(firstValidFrames) + lookAhead);

varIM = nan(H,W,'single');
varPred = nan(H,W,'single');

for r0 = 1:tileSize:H
    r1 = min(H, r0+tileSize-1);
    for c0 = 1:tileSize:W
        c1 = min(W, c0+tileSize-1);
        validTile = valid(r0:r1,c0:c1);
        if ~any(validTile,'all')
            continue
        end

        raw = IM(r0:r1,c0:c1,1:calEnd);
        raw = applyValidityMask(raw, validTile);
        v = readVarianceBlock(varSource, r0, r1, c0, c1, 1, calEnd);
        v(isnan(raw)) = nan;

        [IMs, vSm] = varianceWeightedSmooth(raw, v, varSmoothWindow);
        IMb = smoothdata(IMs, 3, 'movmedian', baselineWindow, 'omitnan');

        fv = firstValidFrames(firstValidFrames <= calEnd);
        varIM(r0:r1,c0:c1) = var(IMs(:,:,fv), 0, 3, 'omitmissing');
        varPred(r0:r1,c0:c1) = ...
            mean(IMb(:,:,fv),3,'omitmissing') .* ...
            mean(vSm(:,:,fv),3,'omitmissing');

        clear raw v IMs vSm IMb
    end
end

varIM(nanFrac>0.4) = nan;
Vb = params.VIF * prctile(varIM, 10, 'all');
brightThresh = prctile(varPred(:), 90);
selBright = varPred > brightThresh;
Vk = prctile((varIM(selBright) - (Vb/params.VIF)) ./ varPred(selBright), 10);

if isempty(Vk) || ~isfinite(Vk)
    error('localizeSources_vIM:VarianceModelFailed', ...
        'Could not estimate the variance-brightness slope Vk.');
end

%% Tile-wise matched filtering and source score accumulation
% imgaussfilt default support is approximately +/- 2*sigma. The broader DoG
% component has sigma=5*sigma, so +/-10*sigma plus one pixel for local-max
% comparison safely protects the core of each tile from tile-edge effects.
halo = max(2, ceil(10*sigma) + 2);
skIm = zeros(H,W,'single');
lastPeakFrame = nTimePoints - ceil(1.5*tau);
gamma = exp(-1/tau);

for r0 = 1:tileSize:H
    r1 = min(H, r0+tileSize-1);
    er0 = max(1, r0-halo);
    er1 = min(H, r1+halo);
    coreR = (r0:r1) - er0 + 1;

    for c0 = 1:tileSize:W
        c1 = min(W, c0+tileSize-1);
        ec0 = max(1, c0-halo);
        ec1 = min(W, c1+halo);
        coreC = (c0:c1) - ec0 + 1;

        validTile = valid(er0:er1,ec0:ec1);
        if ~any(validTile(coreR,coreC),'all')
            skIm(r0:r1,c0:c1) = nan;
            continue
        end

        raw = IM(er0:er1,ec0:ec1,:);
        raw = applyValidityMask(raw, validTile);
        nansTile = isnan(raw);

        v = readVarianceBlock(varSource, er0, er1, ec0, ec1, 1, nTimePoints);
        v(nansTile) = nan;

        [IMs, vSm] = varianceWeightedSmooth(raw, v, varSmoothWindow);
        IMb = smoothdata(IMs, 3, 'movmedian', baselineWindow, 'omitnan');

        % High-pass and normalize by estimated uncertainty.
        Z = (raw - IMb) ./ sqrt(max(0, Vk .* IMb .* vSm) + Vb);
        clear raw v IMs vSm IMb

        % Time-matched causal/reverse exponential filter. Keep the internal
        % memory state even where the original sample is NaN, then restore
        % NaNs exactly as in the legacy implementation.
        mem = max(0, gamma * Z(:,:,end));
        for t = nTimePoints:-1:1
            Zt = Z(:,:,t);
            nt = isnan(Zt);
            Zt(nt) = mem(nt);
            Z(:,:,t) = gamma*mem + (1-gamma)*Zt;
            mem = Z(:,:,t);
        end
        Z(nansTile) = nan;

        % Difference of Gaussians in space only.
        Z(nansTile) = 0;
        dog = imgaussfilt(Z, [sigma sigma]);
        dog = dog - imgaussfilt(Z, 5*[sigma sigma]);
        clear Z
        dog(nansTile) = nan;

        tileSk = zeros(size(dog,1),size(dog,2),'single');
        for fr = lastPeakFrame:-1:2
            IMfr = dog(:,:,fr);
            IMpre = dog(:,:,fr-1);
            IMpost = dog(:,:,fr+1);
            selMax = IMfr == ordfilt2(IMfr, 9, ones(3));
            peakMask = selMax & IMfr>IMpre & IMfr>=IMpost;
            tileSk(peakMask) = tileSk(peakMask) + IMfr(peakMask).^2;
        end

        if lastPeakFrame >= 2
            obsCount = sum(~nansTile(:,:,2:lastPeakFrame), 3);
        else
            obsCount = zeros(size(tileSk),'single');
        end
        tileSk = tileSk ./ (300 + single(obsCount));

        skIm(r0:r1,c0:c1) = tileSk(coreR,coreC);
        clear dog tileSk nansTile mem
    end
end

%% Legacy summary/peak-selection stage
summaryEroded = skIm;
maxVal = max(summaryEroded(:), [], 'omitnan');
if isempty(maxVal) || ~isfinite(maxVal) || maxVal <= 0
    P = [];
    skIm(~valid) = nan;
    return
end
summaryEroded = summaryEroded ./ 10^(floor(log10(maxVal))-1);
summaryEroded(~valid) = nan;
mfSummary = nanmedfilt2(summaryEroded, [5 5]);
summaryEroded = summaryEroded - mfSummary;
summaryEroded(~valid) = nan;
skIm(~valid) = nan;

thetaf = getActImPeaks(summaryEroded, params.peakth, [], params.minPeakDistance);
if isempty(thetaf)
    P = struct('row', [], 'col', [], 'val', [], 'peakIM', []);
else
    P.row = thetaf(:,2);
    P.col = thetaf(:,3);
    P.val = thetaf(:,1);
    peaksMask = zeros(size(summaryEroded),'single');
    peaksMask(sub2ind(size(peaksMask), round(P.row), round(P.col))) = 1;
    P.peakIM = summaryEroded .* peaksMask;
end

if doPlot
    figure, imagesc(summaryEroded);
    hold on
    if ~isempty(P) && isfield(P,'col') && ~isempty(P.col)
        scatter(P.col, P.row, 20*P.val, 'r');
    end
    figure, imagesc(summaryEroded);
end
end


function raw = applyValidityMask(raw, valid2D)
% Mask pixels that fail the whole-trial NaN-fraction criterion.
if all(valid2D,'all')
    return
end
bad = ~valid2D;
for t = 1:size(raw,3)
    frame = raw(:,:,t);
    frame(bad) = nan;
    raw(:,:,t) = frame;
end
end


function [IMs, vSm] = varianceWeightedSmooth(raw, v, varSmoothWindow)
% Match the legacy variance-weighted temporal smoothing exactly.
IMs = smoothdata(raw./v, 3, 'movmean', varSmoothWindow, 'omitnan');
vSm = 1 ./ smoothdata(1./v, 3, 'movmean', varSmoothWindow, 'omitnan');
IMs = IMs .* vSm;
end


function [source, cleanupObj] = prepareVarianceSource(vIM, movieSize, tileSize, params)
% Normalize numeric/empty/on-disk variance inputs to a common accessor.
cleanupObj = [];

if isempty(vIM)
    source.type = 'ones';
    source.size = movieSize;
    return
end

if isnumeric(vIM)
    if ~isequal(size(vIM), movieSize)
        error('localizeSources_vIM:VarianceSizeMismatch', ...
            'Numeric vIM size %s does not match movie size %s.', ...
            mat2str(size(vIM)), mat2str(movieSize));
    end
    source.type = 'numeric';
    source.data = vIM;
    source.size = movieSize;
    return
end

if ~isstruct(vIM) || ~isfield(vIM,'filename') || ~isfield(vIM,'dataset')
    error('localizeSources_vIM:InvalidVarianceSource', ...
        'vIM must be empty, numeric, or a struct with filename/dataset.');
end

info = h5info(vIM.filename, vIM.dataset);
if ~isequal(double(info.Dataspace.Size(:))', double(movieSize(:))')
    error('localizeSources_vIM:VarianceSizeMismatch', ...
        'HDF5 variance size %s does not match movie size %s.', ...
        mat2str(info.Dataspace.Size), mat2str(movieSize));
end

source.type = 'h5';
source.filename = vIM.filename;
source.dataset = vIM.dataset;
source.size = movieSize;

% Old optimized MultiRoiRegistration files used H x W x 1 chunks. Those are
% excellent for frame-wise writes but pathological for spatial-tile reads:
% every tile touches every full-frame chunk. Rechunk once to a local temp H5.
chunk = [];
if isfield(info, 'ChunkSize')
    chunk = info.ChunkSize;
end
needsCache = isempty(chunk) || ...
    (numel(chunk)>=2 && (chunk(1) > 2*tileSize || chunk(2) > 2*tileSize));

if ~needsCache
    return
end

if isfield(params,'localizationTempDir') && ~isempty(params.localizationTempDir)
    tempDr = char(params.localizationTempDir);
else
    tempDr = tempdir;
end
if ~isfolder(tempDr)
    mkdir(tempDr);
end

cacheFn = [tempname(tempDr) '_GIAnT_varFacDS.h5'];
fprintf('Rechunking varFacDS to local temporary cache:\n  %s\n', cacheFn);

H = movieSize(1); W = movieSize(2); T = movieSize(3);
tChunk = min(8,T);
h5create(cacheFn, '/varFacDS', movieSize, ...
    'Datatype', 'single', ...
    'ChunkSize', [min(tileSize,H), min(tileSize,W), tChunk]);

for t0 = 1:tChunk:T
    nt = min(tChunk, T-t0+1);
    block = h5read(vIM.filename, vIM.dataset, [1 1 t0], [H W nt]);
    h5write(cacheFn, '/varFacDS', single(block), [1 1 t0], [H W nt]);
end

source.filename = cacheFn;
source.dataset = '/varFacDS';
cleanupObj = onCleanup(@() deleteIfExists(cacheFn));
end


function v = readVarianceBlock(source, r0, r1, c0, c1, t0, t1)
nr = r1-r0+1;
nc = c1-c0+1;
nt = t1-t0+1;

switch source.type
    case 'ones'
        v = ones(nr,nc,nt,'single');
    case 'numeric'
        v = source.data(r0:r1,c0:c1,t0:t1);
        if ~isa(v,'single')
            v = single(v);
        end
    case 'h5'
        v = h5read(source.filename, source.dataset, ...
            [r0 c0 t0], [nr nc nt]);
        if ~isa(v,'single')
            v = single(v);
        end
    otherwise
        error('localizeSources_vIM:UnknownVarianceSource', ...
            'Unknown variance source type: %s', source.type);
end
end


function deleteIfExists(fn)
if isfile(fn)
    try
        delete(fn);
    catch ME
        warning('localizeSources_vIM:TempCleanupFailed', ...
            'Could not delete temporary variance cache %s: %s', fn, ME.message);
    end
end
end
