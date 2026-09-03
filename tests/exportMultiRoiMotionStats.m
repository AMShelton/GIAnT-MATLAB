function out = exportMultiRoiMotionStats(h5Paths, outPath, maxshift)
%EXPORTMULTIROIMOTIONSTATS Export compact motion/runtime diagnostics from
% one or more GIAnT *_ALIGNMENTDATA.h5 files.
%
% Usage:
%   out = exportMultiRoiMotionStats(h5Paths)
%   out = exportMultiRoiMotionStats(h5Paths, outPath)
%   out = exportMultiRoiMotionStats(h5Paths, outPath, maxshift)
%
% h5Paths may be:
%   - a char/string path to one file
%   - a char/string folder containing *_ALIGNMENTDATA.h5
%   - a cell array/string array of file paths
%
% The output contains only small vectors/tables; no images or varFacDS data.

if nargin < 1 || isempty(h5Paths)
    error('Provide one or more alignment H5 paths or a folder.');
end

if nargin < 3 || isempty(maxshift)
    maxshift = inf;
end

files = normalizeInput(h5Paths);
if isempty(files)
    error('No *_ALIGNMENTDATA.h5 files found.');
end

rows = table();
perFile = repmat(struct(), numel(files), 1);

for i = 1:numel(files)
    fn = files{i};

    r = double(h5read(fn, '/motionDSr')); r = r(:);
    c = double(h5read(fn, '/motionDSc')); c = c(:);

    n = min(numel(r), numel(c));
    r = r(1:n); c = c(1:n);

    prevR = [0; round(r(1:end-1))];
    prevC = [0; round(c(1:end-1))];
    if isfinite(maxshift)
        prevR = max(-maxshift, min(maxshift, prevR));
        prevC = max(-maxshift, min(maxshift, prevC));
    end
    residR = r - prevR;
    residC = c - prevC;

    finite = isfinite(residR) & isfinite(residC);
    residR = residR(finite);
    residC = residC(finite);
    absMax = max(abs([residR residC]), [], 2);

    pf = struct();
    pf.file = fn;
    pf.nFrames = n;
    pf.motionR = r;
    pf.motionC = c;
    pf.residualR = residR;
    pf.residualC = residC;
    pf.absResidualMax = absMax;
    pf.runtime = readRuntime(fn);
    pf.datasetInfo = readDatasetInfo(fn);
    perFile(i) = pf;

    T = table(repmat(string(fn), numel(residR), 1), ...
        (1:numel(residR))', residR, residC, absMax, ...
        'VariableNames', {'file','frame','residualR','residualC','absResidualMax'});
    rows = [rows; T]; %#ok<AGROW>
end

x = rows.absResidualMax;
summary = struct();
summary.nFiles = numel(files);
summary.nFrames = height(rows);
summary.pctWithin1px = 100*mean(x <= 1);
summary.pctWithin2px = 100*mean(x <= 2);
summary.pctWithin3px = 100*mean(x <= 3);
summary.pctWithin4px = 100*mean(x <= 4);
summary.pctAtOrBeyond5px = 100*mean(x >= 5);
summary.quantiles = prctile(x, [50 90 95 99 99.5 99.9 100]);
summary.quantileLabels = {'p50','p90','p95','p99','p99_5','p99_9','max'};

out = struct();
out.summary = summary;
out.frames = rows;
out.perFile = perFile;
out.maxshiftUsed = maxshift;

fprintf('\nMultiROI residual-motion summary (%d files, %d frames)\n', ...
    summary.nFiles, summary.nFrames);
fprintf('  within +/-1 px: %.4f %%\n', summary.pctWithin1px);
fprintf('  within +/-2 px: %.4f %%\n', summary.pctWithin2px);
fprintf('  within +/-3 px: %.4f %%\n', summary.pctWithin3px);
fprintf('  within +/-4 px: %.4f %%\n', summary.pctWithin4px);
fprintf('  >= 5 px:        %.4f %%\n', summary.pctAtOrBeyond5px);
fprintf('  residual |max axis| quantiles:\n');
for k = 1:numel(summary.quantiles)
    fprintf('    %-6s %.6f px\n', summary.quantileLabels{k}, summary.quantiles(k));
end

if nargin >= 2 && ~isempty(outPath)
    outPath = char(outPath);
    [od,~,ext] = fileparts(outPath);
    if ~isempty(od) && ~exist(od,'dir')
        mkdir(od);
    end
    if isempty(ext)
        outPath = [outPath '.mat'];
    end
    save(outPath, 'out', '-v7');
    fprintf('Saved compact diagnostics to:\n  %s\n', outPath);
end
end

function files = normalizeInput(x)
if ischar(x) || (isstring(x) && isscalar(x))
    p = char(x);
    if isfolder(p)
        d = dir(fullfile(p, '*_ALIGNMENTDATA.h5'));
        files = fullfile({d.folder}, {d.name});
    else
        files = {p};
    end
elseif isstring(x)
    files = cellstr(x(:));
elseif iscell(x)
    files = x(:);
else
    error('Unsupported input type for h5Paths.');
end
files = files(cellfun(@(f) exist(f,'file')==2, files));
end

function rt = readRuntime(fn)
rt = struct();
names = {'readerSetup_s','initialRead_s','initialCorrelation_s','getImages_s', ...
    'correlation_s','interpolation_s','templateUpdate_s','tiffWrite_s', ...
    'h5Write_s','qc_s','profiledTotal_s','wall_s','registrationBlockFrames', ...
    'onlineMotion_s','finalH5_s','core_s','total_s'};
for k = 1:numel(names)
    path = ['/runtime/' names{k}];
    try
        rt.(names{k}) = double(h5read(fn, path));
    catch
        rt.(names{k}) = NaN;
    end
end
end

function info = readDatasetInfo(fn)
info = struct();
paths = {'/motionDSr','/motionDSc','/meanIM','/slap2/varFacDS','/DSframes'};
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
