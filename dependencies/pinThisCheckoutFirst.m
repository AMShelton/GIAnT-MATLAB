function repoRoot = pinThisCheckoutFirst(callerPath)
%PINTHISCHECKOUTFIRST Put the GIAnT checkout containing CALLERPATH first on the path.
%   repoRoot = pinThisCheckoutFirst(mfilename('fullpath'))
%   Walks up from the caller to the folder holding 'dependencies', prepends
%   that tree (addpath -begin) and rehashes, so this checkout shadows any other
%   repository defining the same function names (SLAP2-Voltage-Extraction
%   ships copies of setParams, saveStructToH5, MultiRoiRegistration, ...).
%   Same rule processSLAP2 applies; this makes direct calls of SILo /
%   MultiRoiRegistration safe too. Parallel workers are pinned separately by
%   refreshPoolWorkerCode. Cheap enough to run on every call.
repoRoot = fileparts(callerPath);
while ~isfolder(fullfile(repoRoot, 'dependencies')) && ~strcmp(repoRoot, fileparts(repoRoot))
    repoRoot = fileparts(repoRoot);
end
if ~isfolder(fullfile(repoRoot, 'dependencies'))
    warning('pinThisCheckoutFirst:NoRepoRoot', 'No dependencies folder found above %s; path not changed.', callerPath);
    return
end
addpath(genpath(repoRoot), '-begin');
rehash;
end
