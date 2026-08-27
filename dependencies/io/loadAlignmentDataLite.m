function s = loadAlignmentDataLite(filename)
%LOADALIGNMENTDATALITE Read GIAnT alignment metadata without varFacDS.
%
%   s = loadAlignmentDataLite(filename)
%
% MultiRoiRegistration stores /slap2/varFacDS as an H x W x T array.
% Loading an alignment H5 with loadStructFromH5 therefore materializes the
% entire variance-factor movie even when callers only need small metadata
% fields. This reader mirrors the H5 hierarchy while deliberately skipping
% /slap2/varFacDS. Source localization can access that dataset lazily from
% disk instead.

if nargin < 1 || isempty(filename)
    error('loadAlignmentDataLite:MissingFilename', ...
        'An alignment H5 filename must be provided.');
end
if ~isfile(filename)
    error('loadAlignmentDataLite:FileNotFound', ...
        'Alignment H5 not found: %s', filename);
end

info = h5info(filename);
s = readGroup(filename, info);
end


function s = readGroup(filename, grpInfo)
s = struct();

for ix = 1:numel(grpInfo.Datasets)
    ds = grpInfo.Datasets(ix);
    if strcmp(grpInfo.Name, '/')
        path = ['/' ds.Name];
    else
        path = [grpInfo.Name '/' ds.Name];
    end

    % Critical RAM optimization: never materialize the variance movie here.
    if strcmp(path, '/slap2/varFacDS')
        continue
    end

    val = h5read(filename, path);
    if isstring(val)
        if isscalar(val)
            val = char(val);
        else
            val = cellstr(val);
        end
    end
    s.(ds.Name) = val;
end

for ix = 1:numel(grpInfo.Groups)
    grp = grpInfo.Groups(ix);
    parts = strsplit(grp.Name, '/');
    grpName = parts{end};
    s.(grpName) = readGroup(filename, grp);
end
end
