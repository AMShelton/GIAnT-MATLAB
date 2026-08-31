function [sdf, meta, cacheHit] = getCachedSlap2Resources(fullPath, reuseReader, action)
%GETCACHEDSLAP2RESOURCES Reuse SLAP2 reader + metadata for pseudo-trials.
%
% Continuous SLAP2 files are divided by GIAnT into many ~20-s analysis
% trials. Reconstructing slap2.Slap2DataFile and reparsing the same metadata
% for every pseudo-trial wastes time and can repeatedly reopen the same file.
%
% If the optimized Slap2DataReader overlay is installed, this helper uses
% slap2.util.getCachedDataFile. Otherwise it provides an equivalent local
% cache, so GIAnT remains backwards compatible with the upstream reader.
%
% action = 'get' (default) or 'clear'.

persistent readerMap metadataMap

if nargin < 2 || isempty(reuseReader)
    reuseReader = true;
end
if nargin < 3 || isempty(action)
    action = 'get';
end
action = lower(char(string(action)));

if isempty(readerMap)
    readerMap = containers.Map('KeyType','char','ValueType','any');
    metadataMap = containers.Map('KeyType','char','ValueType','any');
end

if strcmp(action,'clear')
    readerMap = containers.Map('KeyType','char','ValueType','any');
    metadataMap = containers.Map('KeyType','char','ValueType','any');

    if exist('slap2.util.getCachedDataFile','file') == 2
        try
            slap2.util.getCachedDataFile('', 'clear');
        catch
            % The reader cache is optional; never make GIAnT depend on it.
        end
    end

    sdf = [];
    meta = [];
    cacheHit = false;
    return
elseif ~strcmp(action,'get')
    error('getCachedSlap2Resources:UnknownAction', ...
        'Unknown cache action "%s".',action);
end

fullPath = char(string(fullPath));
if ispc
    key = lower(strrep(fullPath,'/','\'));
else
    key = fullPath;
end

if ~reuseReader
    sdf = slap2.Slap2DataFile(fullPath);
    meta = loadMetadata(fullPath);
    cacheHit = false;
    return
end

cacheHit = false;

% Prefer the cache supplied with the optimized reader overlay when present.
if exist('slap2.util.getCachedDataFile','file') == 2
    try
        [sdf, readerHit] = slap2.util.getCachedDataFile(fullPath);
        cacheHit = logical(readerHit);
    catch
        sdf = [];
    end
else
    sdf = [];
end

% Backwards-compatible GIAnT-side fallback.
if isempty(sdf)
    if isKey(readerMap,key)
        sdf = readerMap(key);
        cacheHit = true;
    else
        sdf = slap2.Slap2DataFile(fullPath);
        readerMap(key) = sdf;
    end
end

if isKey(metadataMap,key)
    meta = metadataMap(key);
else
    meta = loadMetadata(fullPath);
    metadataMap(key) = meta;
end
end
