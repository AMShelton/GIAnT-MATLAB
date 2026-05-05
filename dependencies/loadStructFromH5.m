function s = loadStructFromH5(filename)
%LOADSTRUCTFROMH5 Read an HDF5 file written by SAVESTRUCTTOH5 into a struct.
%   s = LOADSTRUCTFROMH5(filename) mirrors the hierarchy written by
%   SAVESTRUCTTOH5. HDF5 groups become nested scalar structs; string
%   datasets become cell arrays of char, except scalar path strings
%   (e.g. datadr, savedr) which become char. filename and output path
%   grids stay cell with the same shape as the dataset (including 1x1).

if nargin < 1 || isempty(filename)
    error('loadStructFromH5:MissingFilename', 'A source filename must be provided.');
end
if ~exist(filename, 'file')
    error('loadStructFromH5:FileNotFound', 'File not found: %s', filename);
end

info = h5info(filename);
s = readGroup(filename, info);
end


function s = readGroup(filename, grpInfo)
%READGROUP Recursively convert an h5info group into a scalar struct.
s = struct();

for ix = 1:numel(grpInfo.Datasets)
    ds = grpInfo.Datasets(ix);
    if strcmp(grpInfo.Name, '/')
        path = ['/' ds.Name];
    else
        path = [grpInfo.Name '/' ds.Name];
    end
    val = h5read(filename, path);
    if isstring(val)
        if h5TrialTableFilenameCellField(ds.Name)
            val = reshape(cellstr(val(:)), size(val));
        elseif isscalar(val)
            val = char(val);
        else
            val = cellstr(val);
        end
    elseif ischar(val) && h5TrialTableFilenameCellField(ds.Name) && isvector(val)
        % Rare: string dataset read as char (e.g. single-trial path)
        val = {strtrim(val(:)')};
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

function tf = h5TrialTableFilenameCellField(name)
persistent known
if isempty(known)
    known = {'filename', 'fn_reg_ds', 'fn_raw', 'fn_adata', 'fn_ann'};
end
tf = any(strcmp(name, known));
end
