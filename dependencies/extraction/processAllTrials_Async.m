function E = processAllTrials_Async(dr, fns, fls, els, selPix, sources, discardFrames, alignData, meanAligned, motOutput, roiData, validTrials, params)
%PROCESSALLTRIALS_ASYNC Load high-resolution trials while source extraction
% runs concurrently on a bounded thread pool.

if ~isfield(params,'extractionWorkers') || isempty(params.extractionWorkers)
    params.extractionWorkers = min(8,params.nWorkers);
end
targetWorkers = max(1,round(params.extractionWorkers));

curPool = gcp('nocreate');
needsPool = isempty(curPool) || ...
    ~strcmpi(class(curPool),'parallel.ThreadPool') || ...
    curPool.NumWorkers ~= targetWorkers;
if needsPool
    delete(curPool);
    parpool('Threads',targetWorkers);
end
fprintf('High-resolution extraction thread workers: %d\n',targetWorkers);

numDatasets = numel(fls);
E = cell(numDatasets,1);

% Keep one SLAP2 reader + parsed metadata object alive across the many
% analysis pseudo-trials that usually point to the same continuous DAT file.
% Clear it automatically when this path finishes or errors.
if params.isSLAP2 && isfield(params,'reuseSlap2Reader') && params.reuseSlap2Reader
    getCachedSlap2Resources('',true,'clear');
    readerCacheCleanup = onCleanup(@() getCachedSlap2Resources('',true,'clear')); %#ok<NASGU>
end

for i = 1:numel(validTrials)
    nLoad = validTrials(i);

    tLoad = tic;
    CD = loadTrial(dr, fns{nLoad},fls(nLoad),els(nLoad),selPix, ...
        discardFrames{nLoad},alignData{nLoad},meanAligned(:,:,:,nLoad), ...
        motOutput(:,nLoad),roiData,params);
    fprintf('Loaded/interpolated trial %d in %.1f s\n',nLoad,toc(tLoad));

    E{nLoad}.ROIs = CD.ROIs;
    E{nLoad}.global = CD.global;
    E{nLoad}.discardFrames = CD.discardFrames;
    E{nLoad}.frameLines = CD.frameLines;

    if i>1
        % Wait for the previous extraction only after loading the next trial.
        % With selected-pixel interpolation the client can perform I/O while
        % thread workers remain busy in the NMF solver.
        prevTrial = validTrials(i-1);
        tFetch = tic;
        E{prevTrial} = processResult(resultsFuture,E{prevTrial},params);
        fprintf('Finalized source extraction for trial %d in %.1f s wait time\n', ...
            prevTrial,toc(tFetch));
    end

    fprintf('Processing trial %d from %s\n',nLoad,fns{nLoad});
    Y = permute(CD.Yobs,[1 3 2]);
    resultsFuture = extractTrial(Y,CD.Finv,sources,any(selPix,3),params,alignData{nLoad});
    clear CD Y;
end

lastTrial = validTrials(end);
tFetch = tic;
E{lastTrial} = processResult(resultsFuture,E{lastTrial},params);
fprintf('Finalized source extraction for trial %d in %.1f s wait time\n', ...
    lastTrial,toc(tFetch));
end

% ---------------- Helper Functions ----------------
function plotE(E, Y,B,selPix) %debugging helper only
    %generate activity movie, baseline movie, and residual
    sel2D = any(selPix,3);
    Ht = reshape(E.footprints,numel(sel2D),[]);
    Ht = Ht(sel2D(:),:);

    Amov = max(0,Ht,'omitmissing')*max(0,E.dF.denoised,'omitmissing');
    Rmov = Y - Amov - B;

    render = zeros([size(sel2D) 500]);
    render(repmat(sel2D,1,1,500)) = B(:,501:1000);
end

function E = processResult(resultsFuture,E,params)
try
    [H,S,LS,F0,SNR] = fetchOutputs(resultsFuture);
    discard = E.discardFrames;
    E.footprints = H;
    E.dF.events = S;
    E.dF.events(:,discard) = nan;

    E.dF.denoised(:,:,1) = convn(S(:,:,1),params.k,'same');
    if size(S,3)>1
        E.dF.denoised(:,:,2) = convn(S(:,:,2),params.k2,'same');
    end
    E.dF.denoised(:,discard,:) = nan;

    E.dF.ls = LS;
    E.dF.ls(:,discard,:) = nan;

    E.F0 = F0;
    E.SNR = SNR;
catch ME
    fprintf(2,'processResult ERROR: %s\n',ME.message);
    rethrow(ME);
end
end

function CD = loadTrial(dr, fn, startLine, endLine, selPix, discardFrames, alignData, meanIM, motOutput, roiData, params)
disp('Loading high-res data for file:')
disp([dr filesep fn])

numChannels = params.numChannels;
orderedChannels = [params.activityChannel:numChannels, 1:params.activityChannel-1];

if params.isSLAP2
        if params.includeIntegrationROIs
            warning('includeIntegration not implemented, using raster only!')
        end
        spTypeFlag = 1; % use raster superpixels

        % Reuse the reader and parsed metadata across continuous-file
        % pseudo-trials. This preserves getImages exactly but avoids repeated
        % file opening / ParsePlan construction.
        reuseReader = true;
        if isfield(params,'reuseSlap2Reader')
            reuseReader = logical(params.reuseSlap2Reader);
        end
        tReaderSetup = tic;
        [S2data,meta,readerCacheHit] = getCachedSlap2Resources( ...
            fullfile(dr,fn),reuseReader);
        readerSetupSeconds = toc(tReaderSetup);

        linerateHz = 1/meta.linePeriod_s;
        dt = linerateHz/params.analyzeHz;
        frameLines = ceil(startLine:dt:endLine);
        nFrames = length(frameLines);
        CD.frameLines = frameLines;

        % Upsample motion exactly as before.
        motionC = interp1(alignData.DSframes,alignData.motionDSc, ...
            frameLines,'pchip','extrap') + motOutput(2);
        motionR = interp1(alignData.DSframes,alignData.motionDSr, ...
            frameLines,'pchip','extrap') + motOutput(1);
        CD.motionC = motionC;
        CD.motionR = motionR;

        alignDataSlap2 = alignData.slap2;
        viewC = alignDataSlap2.viewC(1,:);
        viewR = alignDataSlap2.viewR(:,1);
        outRows = numel(viewR);
        outCols = numel(viewC);

        selPx2D = any(selPix,3);
        selPx2D = selPx2D(1:outRows,1:outCols);
        meanIM = meanIM(1:outRows,1:outCols,:);

        % Pixels used by the global trace.
        labeledScore = medfilt2(meanIM(:,:,params.activityChannel),[3 3]);
        validScore = labeledScore(~isnan(labeledScore));
        if isempty(validScore)
            labeled = false(outRows,outCols);
        else
            labeled = ~isnan(meanIM(:,:,params.activityChannel)) & ...
                labeledScore > 3*prctile(validScore,25);
        end

        meanPx = reshape(meanIM,outRows*outCols,numChannels);
        meanPxOrdered = meanPx(:,orderedChannels);
        mLabeled = meanPxOrdered(labeled,:);
        sumF = sum(meanPxOrdered,1,'omitmissing');

        % Build the union of every output pixel required downstream. The old
        % pathway motion-corrected the complete FOV at 200 Hz and discarded
        % most pixels immediately afterwards.
        neededPx2D = selPx2D | labeled;
        roiMasks = cell(1,numel(roiData));
        for rix = 1:numel(roiData)
            mask = logical(roiData{rix}.mask);
            maskRows = min(size(mask,1),outRows);
            maskCols = min(size(mask,2),outCols);
            mask = mask(1:maskRows,1:maskCols);
            tmpMask = false(outRows,outCols);
            tmpMask(1:size(mask,1),1:size(mask,2)) = mask;
            roiMasks{rix} = tmpMask;
            neededPx2D = neededPx2D | tmpMask;
        end

        neededLin = find(neededPx2D);
        nNeeded = numel(neededLin);
        nOutPx = outRows*outCols;
        neededMap = zeros(nOutPx,1,'uint32');
        neededMap(neededLin) = uint32(1:nNeeded);

        sourceNeeded = double(neededMap(find(selPx2D)));
        globalNeeded = double(neededMap(find(labeled)));
        roiNeeded = cell(1,numel(roiData));
        for rix = 1:numel(roiData)
            roiNeeded{rix} = double(neededMap(find(roiMasks{rix})));
        end

        if ~isfield(params,'highResBlockFrames') || isempty(params.highResBlockFrames)
            params.highResBlockFrames = 600;
        end
        requestedBlocksize = max(1,round(params.highResBlockFrames));

        % Larger blocks reduce getImages/MEX call overhead on local SSDs,
        % but bound the full-raster temporary arrays by an explicit memory
        % budget. The estimate intentionally assumes double precision and
        % includes both Y and Fresh plus overhead, so it is conservative.
        blocksize = requestedBlocksize;
        if isfield(params,'highResBlockMemoryGB') && ...
                ~isempty(params.highResBlockMemoryGB) && ...
                isfinite(params.highResBlockMemoryGB)
            rawRowsEstimate = max(double(alignDataSlap2.trimRows(:)));
            rawColsEstimate = max(double(alignDataSlap2.trimCols(:)));
            rawPxEstimate = max(1,rawRowsEstimate*rawColsEstimate);
            bytesPerFrameEstimate = 8*rawPxEstimate*(numChannels+1)*1.35;
            memoryBytes = double(params.highResBlockMemoryGB)*(1024^3);
            maxFramesByMemory = max(1,floor(memoryBytes/bytesPerFrameEstimate));
            blocksize = min(blocksize,maxFramesByMemory);
        end

        nSourcePx = nnz(selPx2D);
        IMsel = nan(nSourcePx,numChannels,nFrames);
        Finvsel = nan(nSourcePx,nFrames);
        CD.global.F = nan(numChannels,nFrames);
        CD.ROIs.F = nan(numel(roiData),numChannels,nFrames);
        CD.ROIs.Fsvd = nan(numel(roiData),numChannels,nFrames);
        Fpx = cell(1,numel(roiData));
        rawReadSeconds = 0;
        selectedInterpSeconds = 0;

        % Forward block order improves local-file read locality. The
        % selected-pixel interpolation is vectorized over small frame batches
        % but remains mathematically identical to interpFramesSelected.
        interpBatchFrames = 64;
        if isfield(params,'selectedInterpBatchFrames') && ...
                ~isempty(params.selectedInterpBatchFrames)
            interpBatchFrames = max(1,round(params.selectedInterpBatchFrames));
        end

        for blockStart = 1:blocksize:nFrames
            fIxs = blockStart:min(nFrames,blockStart+blocksize-1);
            tRaw = tic;
            [Y,Fresh] = S2data.getImages(orderedChannels,frameLines(fIxs), ...
                ceil(dt),1,spTypeFlag);
            rawReadSeconds = rawReadSeconds + toc(tRaw);
            Y = Y(alignDataSlap2.trimRows,alignDataSlap2.trimCols,:,:);
            Fresh = Fresh(alignDataSlap2.trimRows,alignDataSlap2.trimCols,:);
            nFramesInBlock = size(Y,4);

            % Deliberately run interpolation on the client while NMF futures
            % from the previous trial occupy the bounded thread pool.
            tInterp = tic;
            [Yneeded,FinvNeeded] = interpFramesSelectedBatch( ...
                Y,viewC,viewR,Fresh,neededLin, ...
                motionC(fIxs),motionR(fIxs),interpBatchFrames);
            selectedInterpSeconds = selectedInterpSeconds + toc(tInterp);

            IMsel(:,:,fIxs) = Yneeded(sourceNeeded,:,:);
            Finvsel(:,fIxs) = FinvNeeded(sourceNeeded,:);

            % Global trace using the same mean-image normalization.
            if ~isempty(globalNeeded)
                yLabeled = double(Yneeded(globalNeeded,:,:));
                validGlobal = ~isnan(yLabeled(:,1,:));
                meanGlobal = reshape(mLabeled,[size(mLabeled,1),numChannels,1]);
                denom = sum(meanGlobal .* validGlobal,1,'omitmissing');
                numer = sum(yLabeled,1,'omitmissing');
                g = reshape(numer,[numChannels,nFramesInBlock]) ./ ...
                    reshape(denom,[numChannels,nFramesInBlock]);
                g = g .* sumF(:);
                CD.global.F(orderedChannels,fIxs) = g;
            end

            % User ROI traces. Keep per-pixel samples only when requested,
            % because they are later used for the existing SVD denoising.
            for rix = 1:numel(roiData)
                idx = roiNeeded{rix};
                tmp1 = Yneeded(idx,:,:);
                Fpx{rix}(:,:,fIxs) = tmp1;

                roiMean = meanPxOrdered(roiMasks{rix}(:),:);
                tmp2 = repmat(roiMean,1,1,nFramesInBlock);
                nans = isnan(tmp1) | isnan(tmp2);
                tmp1(nans) = 0;
                tmp2(nans) = 0;
                numer = reshape(sum(tmp1,1),[numChannels,nFramesInBlock]);
                denom = reshape(sum(tmp2,1),[numChannels,nFramesInBlock]);
                roiF = numer./denom .* sum(roiMean,1,'omitmissing')';
                CD.ROIs.F(rix,orderedChannels,fIxs) = reshape(roiF,[1 numChannels nFramesInBlock]);
            end

            clear Y Fresh Yneeded FinvNeeded
        end

        fprintf(['  high-res blocks: getImages %.1f s; selected interpolation ' ...
            '%.1f s; needed pixels %d/%d (%.1f%%); block %d frames; ' ...
            'reader setup %.2f s (%s)\n'], ...
            rawReadSeconds,selectedInterpSeconds,nNeeded,nOutPx, ...
            100*nNeeded/max(1,nOutPx),blocksize,readerSetupSeconds, ...
            ternary(readerCacheHit,'cache hit','new reader'));

        % Existing user-ROI SVD denoising.
        for rix = 1:numel(roiData)
            if ~isempty(Fpx{rix}) && ~all(isnan(Fpx{rix}(:)))
                for cix = 1:numel(orderedChannels)
                    Dtmp = squeeze(double(Fpx{rix}(:,cix,:)));
                    [UU,SS,VV,bg] = nansvd(Dtmp,3,10,params.nanThresh);
                    roiLikeness = ...
                        (abs(mean(UU,1,'omitnan'))./sqrt(mean(UU.^2,1,'omitnan')))*SS;
                    [~,selPC] = max(roiLikeness);
                    CD.ROIs.Fsvd(rix,orderedChannels(cix),:) = ...
                        mean(bg+(UU(:,selPC)*SS(selPC,selPC)*VV(:,selPC)'),1,'omitnan');
                end
            end
        end

    else
        if endsWith(fn, '.h5')
            desc = h5info([dr filesep fn]);
            IM = h5read([dr filesep fn], ['/', desc.Datasets.Name]);
        else
            IM = ScanImageTiffWrapper([dr filesep fn]);
        end
        IM = double(IM);

        %rearrange into correct dimensions
        selPx2D = any(selPix,3);
        IM = reshape(IM, size(IM,1), size(IM,2), numChannels, []);
        baseline = prctile(reshape(median(IM,4,'omitmissing'), [], numChannels), 5,1);
        IM = IM-reshape(baseline, [1 1 numChannels 1]); %subtract baseline
        nPx = size(IM,1)*size(IM,2);
        nFrames = size(IM,4);
        CD.frameLines = 1:nFrames;

        %upsample motion
        viewC = (1:size(IM,2)) + motOutput(2);
        viewR = (1:size(IM,1))' + motOutput(1);

        CD.motionC = alignData.motionC;
        CD.motionR = alignData.motionR;
        
        meanIM = meanIM(1:size(IM,1), 1:size(IM,2),:);
        scored = medfilt2(meanIM(:,:,params.activityChannel), [3 3]);
        scored = (scored-prctile(scored(:),25,'all'))./(prctile(scored(:),99,'all')-prctile(scored(:),25,'all'));
        labeled = scored>0.1;
        meanPx = reshape(meanIM, numel(labeled), numChannels);
        mLabeled = meanPx(labeled,:);

        blocksize = 600; %number of frames to load at a time;
        nBlocks = ceil(nFrames./blocksize);
        blockEdges = round(linspace(1, nFrames+1, nBlocks+1));

        sumF = sum(meanPx,1,'omitmissing');
        IMsel = nan(sum(selPx2D(:)),numChannels, nFrames);
        Finvsel = nan(sum(selPx2D(:)),nFrames);
        Fresh = ones(size(IM,1), size(IM,2), 'single'); %freshness currently unused for non-SLAP2
        for bix = nBlocks:-1:1
            fIxs  = blockEdges(bix):(blockEdges(bix+1)-1);
            nFramesInBlock = length(fIxs);
            
            Y = IM(:,:,:,fIxs); %reduce communication overhead to parallel workers
            nanMask = isnan(Y);
            Y2 = nan(length(viewR),length(viewC),numChannels, nFramesInBlock);
            Finv = nan(length(viewR),length(viewC),nFramesInBlock);
            parfor frIx = 1:nFramesInBlock
                [Y2(:,:,:,frIx), Finv(:,:,frIx)] = interpFrames(Y(:,:,orderedChannels,frIx),viewC, viewR, Fresh);
            end
            Y2(nanMask) = nan;

            Y2 = reshape(Y2, nPx, numChannels, nFramesInBlock);
            Finv= reshape(Finv, nPx, nFramesInBlock);

            IMsel(:, :, fIxs) = Y2(selPx2D,:,:);
            Finvsel(:,fIxs) = Finv(selPx2D,:);

            %compute global ROI activity
            yLabeled = double(Y2(labeled(:),:,:)); nans= isnan(yLabeled(:,1,:));
            M = repmat(mLabeled,1,1,nFramesInBlock); M(nans) = nan;
            CD.global.F(orderedChannels,fIxs) = (sum(yLabeled,1, 'omitmissing')./sum(M,1, 'omitmissing')).*sumF;

            %compute user ROI activity
            for rix = length(roiData):-1:1
                mask = roiData{rix}.mask;
                tmp1 = Y2(mask(:),:,:);  %the data over the ROI pixels
                Fpx{rix}(:,:,fIxs) = tmp1;
                tmp2 = repmat(meanPx(mask(:),:), 1,1,numel(fIxs)); %the mean image over the ROI pixels
                nans= isnan(tmp1) | isnan(tmp2);
                tmp1(nans) = 0;
                tmp2(nans) = 0;
                CD.ROIs.F(rix,:,fIxs) = (sum(tmp1,1)./sum(tmp2,1)).*sum(meanPx(mask(:),:),1,'omitmissing'); %dFF over the valid pixels, times the mean
            end
        end

        %perform SVD on user ROIs to denoise
        CD.ROIs.Fsvd = nan(length(roiData), numChannels, nFrames);
        for rix = 1:length(roiData)
            if ~isempty(Fpx{rix}) && ~all(isnan(Fpx{rix}(:)))
                for cix = 1:numel(orderedChannels)
                    Dtmp = squeeze(double(Fpx{rix}(:,cix,:)));
                    [UU,SS,VV,bg] = nansvd(Dtmp,3, 10, params.nanThresh);
                    roiLikeness = (abs(mean(UU,1, 'omitnan'))./sqrt(mean(UU.^2,1, 'omitnan')))*SS;
                    [~,selPC] = max(roiLikeness);
                    CD.ROIs.Fsvd(rix,cix,:) = mean(bg+(UU(:,selPC)*SS(selPC,selPC)*VV(:,selPC)'),1, 'omitnan');
                end
            end
        end
end

discard = interp1(1:numel(discardFrames), double(discardFrames(:)), linspace(1, numel(discardFrames), size(IMsel,3)))>0; %upsample the discard frames
IMsel(:,:,discard) = nan;     %throw away movement frames as above
IMsel(IMsel<-2*std(IMsel,0,3, 'omitmissing')) = nan; %throw away any aberrantly negative data
CD.global.F(:,discard) = nan;
CD.ROIs.F(:, :, discard) = nan;
CD.ROIs.Fsvd(:,:,discard) = nan;

% Remove nans from IMsel and Finvsel
nans = isnan(IMsel);
nanFill = IMsel;
nanFill(all(nans,3)) = 0;
while any(isnan(nanFill), 'all')
    nanFill = smoothdata(nanFill,3,"movmean",params.baselineWindow_samps, 'omitmissing');
end
IMsel(nans) = nanFill(nans); 
Finvsel(squeeze(nans(:,1,:))) = 1000*mean(Finvsel,'all', 'omitmissing');

CD.Yobs = IMsel;
CD.Finv = Finvsel;
CD.discardFrames = discard;
end

function out = ternary(condition,trueValue,falseValue)
%TERNARY Small local helper for compact diagnostic messages.
if condition
    out = trueValue;
else
    out = falseValue;
end
end
