function out = exportMultiRoiMotionStats_v2(h5Paths, outPath, maxshift)
%EXPORTMULTIROIMOTIONSTATS Export compact motion/runtime diagnostics from
% one or more GIAnT *_ALIGNMENTDATA.h5 files.
%
% Usage:
%   out = exportMultiRoiMotionStats_v2(h5Paths)
%   out = exportMultiRoiMotionStats_v2(h5Paths, outPath)
%   out = exportMultiRoiMotionStats_v2(h5Paths, outPath, maxshift)
%
% h5Paths may be:
%   - a char/string path to one file
%   - a char/string folder containing *_ALIGNMENTDATA.h5
%   - a cell array/string array of file paths
%
% maxshift should match MultiRoiRegistration params.maxshift. It is used
% only when reconstructing the previous-frame search center.
%
% The output contains only small vectors/tables; no images or varFacDS data.

if nargin < 1 || isempty(h5Paths)
    error('exportMultiRoiMotionStats_v2:MissingInput', ...
        'Provide one or more alignment H5 paths or a folder.');
end

if nargin < 2
    outPath = '';
end

if nargin < 3 || isempty(maxshift)
    maxshift = inf;
end

if ~(isscalar(maxshift) && isnumeric(maxshift) && isreal(maxshift) && ...
        (isinf(maxshift) || (isfinite(maxshift) && maxshift >= 0)))
    error('exportMultiRoiMotionStats_v2:InvalidMaxshift', ...
        'maxshift must be a nonnegative finite scalar or Inf.');
end

files = normalizeInput(h5Paths);
if isempty(files)
    error('exportMultiRoiMotionStats_v2:NoFiles', ...
        'No existing *_ALIGNMENTDATA.h5 files were found.');
end

rows = table();

% Use a cell array while building per-file structs. MATLAB does not permit
% assigning a populated struct into a preallocated fieldless struct array.
perFileCell = cell(numel(files), 1);

for i = 1:numel(files)
    fn = files{i};

    r = double(h5read(fn, '/motionDSr'));
    c = double(h5read(fn, '/motionDSc'));
    r = r(:);
    c = c(:);

    n = min(numel(r), numel(c));
    r = r(1:n);
    c = c(1:n);

    % MultiRoiRegistration uses the rounded previous motion estimate as the
    % local-search center, clamped to +/- maxshift.
    prevR = [0; round(r(1:end-1))];
    prevC = [0; round(c(1:end-1))];

    if isfinite(maxshift)
        prevR = max(-maxshift, min(maxshift, prevR));
        prevC = max(-maxshift, min(maxshift, prevC));
    end

    residRAll = r - prevR;
    residCAll = c - prevC;

    finiteMask = isfinite(residRAll) & isfinite(residCAll);
    frameIx = find(finiteMask);
    residR = residRAll(finiteMask);
    residC = residCAll(finiteMask);
    absMax = max(abs([residR residC]), [], 2);

    pf = struct();
    pf.file = fn;
    pf.nFrames = n;
    pf.nFiniteResidualFrames = numel(residR);
    pf.motionR = r;
    pf.motionC = c;
    pf.residualFrameIx = frameIx;
    pf.residualR = residR;
    pf.residualC = residC;
    pf.absResidualMax = absMax;
    pf.runtime = readRuntime(fn);
    pf.datasetInfo = readDatasetInfo(fn);
    perFileCell{i} = pf;

    T = table( ...
        repmat(string(fn), numel(residR), 1), ...
        frameIx, ...
        residR, ...
        residC, ...
        absMax, ...
        'VariableNames', {'file','frame','residualR','residualC','absResidualMax'});
    rows = [rows; T]; %#ok<AGROW>
end

% All pf structs have identical fields, so concatenation is safe here.
perFile = vertcat(perFileCell{:});

x = rows.absResidualMax;

summary = struct();
summary.nFiles = numel(files);
summary.nFrames = height(rows);
summary.maxshiftUsed = maxshift;

if isempty(x)
    summary.pctWithin1px = NaN;
    summary.pctWithin2px = NaN;
    summary.pctWithin3px = NaN;
    summary.pctWithin4px = NaN;
    summary.pctAtOrBeyond5px = NaN;
    summary.quantiles = nan(1,7);
else
    summary.pctWithin1px = 100 * mean(x <= 1);
    summary.pctWithin2px = 100 * mean(x <= 2);
    summary.pctWithin3px = 100 * mean(x <= 3);
    summary.pctWithin4px = 100 * mean(x <= 4);
    summary.pctAtOrBeyond5px = 100 * mean(x >= 5);
    summary.quantiles = prctile(x, [50 90 95 99 99.5 99.9 100]);
end

summary.quantileLabels = {'p50','p90','p95','p99','p99_5','p99_9','max'};

out = struct();
out.summary = summary;
out.frames = rows;
out.perFile = perFile;
out.maxshiftUsed = maxshift;

fprintf('\nMultiROI residual-motion summary (%d files, %d finite frames)\n', ...
    summary.nFiles, summary.nFrames);
if isfinite(maxshift)
    fprintf('  search-center clamp: +/- %.3f px\n', maxshift);
else
    fprintf('  search-center clamp: not applied (maxshift = Inf)\n');
end
fprintf('  within +/-1 px: %.4f %%\n', summary.pctWithin1px);
fprintf('  within +/-2 px: %.4f %%\n', summary.pctWithin2px);
fprintf('  within +/-3 px: %.4f %%\n', summary.pctWithin3px);
fprintf('  within +/-4 px: %.4f %%\n', summary.pctWithin4px);
fprintf('  >= 5 px:        %.4f %%\n', summary.pctAtOrBeyond5px);
fprintf('  residual |max axis| quantiles:\n');
for k = 1:numel(summary.quantiles)
    fprintf('    %-6s %.6f px\n', ...
        summary.quantileLabels{k}, summary.quantiles(k));
end

if ~isempty(outPath)
    outPath = char(string(outPath));
    [od,~,ext] = fileparts(outPath);

    if ~isempty(od) && ~exist(od,'dir')
        mkdir(od);
    end

    if isempty(ext)
        outPath = [outPath '.mat'];
    elseif ~strcmpi(ext,'.mat')
        error('exportMultiRoiMotionStats_v2:OutputExtension', ...
            'outPath must have a .mat extension or no extension.');
    end

    save(outPath, 'out', '-v7');
    fprintf('Saved compact diagnostics to:\n  %s\n', outPath);
end
end


function files = normalizeInput(x)
%NORMALIZEINPUT Return a column cell array of char file paths.

if ischar(x)
    raw = {x};

elseif isstring(x)
    if isscalar(x) && isfolder(char(x))
        raw = {char(x)};
    else
        raw = cellstr(x(:));
    end

elseif iscell(x)
    raw = cell(numel(x),1);
    for i = 1:numel(x)
        item = x{i};
        if isstring(item) && isscalar(item)
            raw{i} = char(item);
        elseif ischar(item)
            raw{i} = item;
        else
            error('exportMultiRoiMotionStats_v2:InvalidCellElement', ...
                'Each h5Paths cell must contain one char vector or string scalar.');
        end
    end

else
    error('exportMultiRoiMotionStats_v2:UnsupportedInput', ...
        'h5Paths must be a path, string array, or cell array of paths.');
end

% A single folder expands to all alignment H5s in that folder.
if numel(raw) == 1 && isfolder(raw{1})
    d = dir(fullfile(raw{1}, '*_ALIGNMENTDATA.h5'));
    files = fullfile({d.folder}, {d.name});
    files = files(:);
    return
end

files = raw(:);

existsMask = cellfun(@(f) exist(f,'file') == 2, files);
if any(~existsMask)
    missing = files(~existsMask);
    warning('exportMultiRoiMotionStats_v2:MissingFiles', ...
        'Ignoring %d missing file(s). First missing path:\n%s', ...
        numel(missing), missing{1});
end
files = files(existsMask);
end


function rt = readRuntime(fn)
rt = struct();

names = { ...
    'readerSetup_s', ...
    'initialRead_s', ...
    'initialCorrelation_s', ...
    'getImages_s', ...
    'correlation_s', ...
    'interpolation_s', ...
    'templateUpdate_s', ...
    'tiffWrite_s', ...
    'h5Write_s', ...
    'qc_s', ...
    'profiledTotal_s', ...
    'wall_s', ...
    'registrationBlockFrames', ...
    'onlineMotion_s', ...
    'finalH5_s', ...
    'core_s', ...
    'total_s'};

for k = 1:numel(names)
    path = ['/runtime/' names{k}];
    try
        value = double(h5read(fn, path));
        if isscalar(value)
            rt.(names{k}) = value;
        else
            rt.(names{k}) = value(:)';
        end
    catch
        rt.(names{k}) = NaN;
    end
end
end


function info = readDatasetInfo(fn)
info = struct();

paths = { ...
    '/motionDSr', ...
    '/motionDSc', ...
    '/meanIM', ...
    '/slap2/varFacDS', ...
    '/DSframes'};

for k = 1:numel(paths)
    key = matlab.lang.makeValidName(strrep(paths{k},'/','_'));
    try
        h = h5info(fn, paths{k});
        info.(key).size = h.Dataspace.Size;
        info.(key).datatype = h.Datatype.Class;
    catch
        info.(key).size = [];
        info.(key).datatype = '';
    end
end
end
