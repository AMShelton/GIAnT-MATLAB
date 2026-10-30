function saveStructToH5(s, filename)
%SAVESTRUCTTOH5 Write a (possibly nested) scalar struct to an HDF5 file.
%   SAVESTRUCTTOH5(s, filename) recursively maps MATLAB struct fields onto
%   the HDF5 hierarchy:
%     - Scalar struct fields become HDF5 groups.
%     - Cell arrays of char/string become variable-length string datasets.
%     - char and string scalars/arrays become string datasets.
%     - Numeric and logical arrays become numeric datasets (logicals as int8).
%     - Empty fields are skipped.
%
%   The destination file is overwritten if it already exists; HDF5 datasets
%   cannot be redefined in place so a fresh file is required.
%
%   Dataset sizes match MATLAB size(val). The file includes /row_major
%   (uint8): 0 = column-major (MATLAB layout). See README.md
%   "Reading H5 outside MATLAB".
%
%   Implementation note (network/SMB robustness): the file is created,
%   populated and closed through the low-level HDF5 API using a SINGLE open
%   file handle. The high-level h5create/h5write/h5info functions reopen the
%   file on every call, and on SMB-backed storage a dataset created by one
%   call was intermittently invisible to the very next reopen ("dataset never
%   became visible after creation"), even with retries. Holding one handle
%   for the whole write removes that failure mode. Only two filesystem-level
%   steps remain and both are retried: creating the file, and a single
%   read-back check of the finished file.
%
%   The on-disk schema is identical to the previous h5create/h5write
%   implementation (same paths, dataspace sizes, native numeric types,
%   variable-length UTF-8 strings, contiguous layout).

if nargin < 2 || isempty(filename)
    error('saveStructToH5:MissingFilename', 'A destination filename must be provided.');
end
if ~isstruct(s) || ~isscalar(s)
    error('saveStructToH5:UnsupportedInput', 'Input must be a scalar struct.');
end

% /row_major is a format flag owned by this writer. A struct that came from
% loadStructFromH5 (e.g. a trial table being updated) carries it as a field;
% drop it so the flag is written exactly once below. The previous h5create
% implementation only tolerated the duplicate because its "already exists"
% error was swallowed by the retry loop before h5write overwrote the value.
if isfield(s, 'row_major')
    s = rmfield(s, 'row_major');
end

% Validate every value BEFORE touching the filesystem, so an unsupported
% type cannot leave a half-written file behind.
validateGroup('', s);

fid = createFileRobust(filename);
closer = onCleanup(@() closeFileIfOpen(fid));

written = writeGroup(fid, '', s, cell(0, 2));   % {path, size} per dataset
written = writeDataset(fid, '/row_major', uint8(0), written);

H5F.close(fid);
clear closer

verifyReadBack(filename, written);
end


% ----------------------------------------------------------------------
% Validation (no file I/O)
% ----------------------------------------------------------------------

function validateGroup(basePath, s)
if ~isstruct(s) || ~isscalar(s)
    error('saveStructToH5:UnsupportedStruct', ...
        'Only scalar structs are supported (at %s).', emptyPathDisplay(basePath));
end
fields = fieldnames(s);
for ix = 1:numel(fields)
    validateValue([basePath '/' fields{ix}], s.(fields{ix}));
end
end


function validateValue(path, val)
if isstruct(val)
    if ~isscalar(val)
        error('saveStructToH5:NonScalarStruct', ...
            'Non-scalar structs are not supported (at %s).', path);
    end
    validateGroup(path, val);
    return;
end
if iscell(val)
    if ~isempty(val) && ~all(cellfun(@(x) ischar(x) || isstring(x) || isempty(x), val(:)))
        error('saveStructToH5:UnsupportedCell', ...
            'Only cell arrays of char/string are supported (at %s).', path);
    end
    return;
end
if ischar(val) || isstring(val) || islogical(val)
    return;
end
if isnumeric(val)
    if isempty(nativeTypeName(class(val)))
        error('saveStructToH5:UnsupportedNumeric', ...
            'Unsupported numeric class ''%s'' at %s.', class(val), path);
    end
    return;
end
error('saveStructToH5:UnsupportedType', ...
    'Unsupported value type ''%s'' at %s.', class(val), path);
end


% ----------------------------------------------------------------------
% Writing (single open file handle)
% ----------------------------------------------------------------------

function written = writeGroup(fid, basePath, s, written)
%WRITEGROUP Recursively write each field of struct s under basePath.
fields = fieldnames(s);
for ix = 1:numel(fields)
    fname = fields{ix};
    path = [basePath '/' fname];
    written = writeValue(fid, path, s.(fname), written);
end
end


function written = writeValue(fid, path, val, written)
%WRITEVALUE Convert a MATLAB value to its on-disk form and write it.
if isstruct(val)
    gid = H5G.create(fid, path, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5G.close(gid);
    written = writeGroup(fid, path, val, written);
    return;
end

if iscell(val)
    if isempty(val)
        return;
    end
    sval = strings(size(val));
    for k = 1:numel(val)
        if isempty(val{k})
            sval(k) = "";
        else
            sval(k) = string(val{k});
        end
    end
    written = writeDataset(fid, path, sval, written);
    return;
end

if ischar(val)
    written = writeDataset(fid, path, string(val), written);   % always [1 1]
    return;
end

if isstring(val)
    if isscalar(val)
        val = reshape(val, 1, 1);
    end
    written = writeDataset(fid, path, val, written);
    return;
end

if islogical(val)
    if isempty(val)
        return;
    end
    written = writeDataset(fid, path, int8(val), written);
    return;
end

% numeric (validated above)
if isempty(val)
    return;
end
val = gather(val);          % collect gpuArray / codistributed
% Round-trip through cast to materialize a plain array of the declared
% class without applying per-element arithmetic.
val = cast(val, class(val));
written = writeDataset(fid, path, val, written);
end


function written = writeDataset(fid, path, val, written)
%WRITEDATASET Create and write one dataset on the already-open file.
% val is either a string array (-> variable-length UTF-8 strings) or a
% numeric array of a supported class. Dataset size equals size(val);
% HDF5 dims are the reverse of MATLAB dims, exactly as h5create/h5write do.
sz = size(val);
if isstring(val)
    tid = H5T.copy('H5T_C_S1');
    H5T.set_size(tid, 'H5T_VARIABLE');
    H5T.set_cset(tid, 'H5T_CSET_UTF8');
    data = cellstr(val);        % keeps shape; "" -> ''
else
    tid = H5T.copy(nativeTypeName(class(val)));
    data = val;
end

sid = H5S.create_simple(numel(sz), fliplr(sz), []);
did = H5D.create(fid, path, tid, sid, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
H5D.write(did, tid, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', data);
H5D.close(did);
H5S.close(sid);
H5T.close(tid);

written(end+1, :) = {path, sz};
end


function name = nativeTypeName(cls)
%NATIVETYPENAME Map a MATLAB numeric class to its HDF5 native type name.
switch cls
    case 'double', name = 'H5T_NATIVE_DOUBLE';
    case 'single', name = 'H5T_NATIVE_FLOAT';
    case 'int8',   name = 'H5T_NATIVE_INT8';
    case 'uint8',  name = 'H5T_NATIVE_UINT8';
    case 'int16',  name = 'H5T_NATIVE_INT16';
    case 'uint16', name = 'H5T_NATIVE_UINT16';
    case 'int32',  name = 'H5T_NATIVE_INT32';
    case 'uint32', name = 'H5T_NATIVE_UINT32';
    case 'int64',  name = 'H5T_NATIVE_INT64';
    case 'uint64', name = 'H5T_NATIVE_UINT64';
    otherwise,     name = '';
end
end


% ----------------------------------------------------------------------
% File open / close / verify (the only filesystem-level steps; retried)
% ----------------------------------------------------------------------

function fid = createFileRobust(filename)
%CREATEFILEROBUST Create (truncate) the destination file with bounded retries.
% H5F_ACC_TRUNC replaces the old delete-then-create sequence, which on SMB
% could race a lingering handle on the just-deleted file (AV scanner, sync
% client). Any objects left open on error are closed with the file
% (H5F_CLOSE_STRONG) so no stale identifiers can block a later reopen.
maxAttempts = 6;
lastError = [];
for attempt = 1:maxAttempts
    fapl = H5P.create('H5P_FILE_ACCESS');
    try
        H5P.set_fclose_degree(fapl, 'H5F_CLOSE_STRONG');
        fid = H5F.create(filename, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', fapl);
        H5P.close(fapl);
        return
    catch ME
        H5P.close(fapl);
        lastError = ME;
        if attempt < maxAttempts
            pause(backoffSeconds(attempt));
        end
    end
end
error('saveStructToH5:H5CreateFileFailed', ...
    'Failed to create HDF5 file %s after %d attempts: %s', ...
    filename, maxAttempts, lastError.message);
end


function closeFileIfOpen(fid)
%CLOSEFILEIFOPEN onCleanup target: close the file if an error left it open.
try
    if H5I.is_valid(fid)
        H5F.close(fid);
    end
catch
end
end


function verifyReadBack(filename, written)
%VERIFYREADBACK Reopen the finished file ONCE and confirm every dataset.
% A single h5info of the whole file replaces the per-dataset h5info polling
% of the previous implementation. Reopen failures are retried with backoff;
% the real HDF5 message is reported if the file still cannot be read, so a
% storage problem is diagnosable rather than "never became visible".
maxChecks = 10;
lastError = [];
for checkIx = 1:maxChecks
    try
        info = h5info(filename);
        found = collectDatasets(info, containers.Map('KeyType','char','ValueType','any'));
        for ix = 1:size(written, 1)
            path = written{ix, 1};
            if ~isKey(found, path)
                error('saveStructToH5:H5DatasetMissing', ...
                    'Dataset %s is missing from %s after writing.', path, filename);
            end
            actualSize = double(found(path));
            expectedSize = double(written{ix, 2});
            if ~isequal(actualSize(:)', expectedSize(:)')
                error('saveStructToH5:H5DatasetSizeMismatch', ...
                    'Dataset %s has size [%s], expected [%s].', path, ...
                    num2str(actualSize), num2str(expectedSize));
            end
        end
        return
    catch ME
        % Schema problems are real bugs, not transient storage delays.
        if any(strcmp(ME.identifier, {'saveStructToH5:H5DatasetMissing', ...
                                       'saveStructToH5:H5DatasetSizeMismatch'}))
            rethrow(ME);
        end
        lastError = ME;
        if checkIx < maxChecks
            pause(backoffSeconds(checkIx));
        end
    end
end
error('saveStructToH5:H5VerifyFailed', ...
    'Wrote %s but could not read it back after %d attempts: %s', ...
    filename, maxChecks, lastError.message);
end


function found = collectDatasets(grpInfo, found)
%COLLECTDATASETS Map of dataset path -> Dataspace.Size for an h5info tree.
for ix = 1:numel(grpInfo.Datasets)
    ds = grpInfo.Datasets(ix);
    if strcmp(grpInfo.Name, '/')
        path = ['/' ds.Name];
    else
        path = [grpInfo.Name '/' ds.Name];
    end
    found(path) = ds.Dataspace.Size;
end
for ix = 1:numel(grpInfo.Groups)
    found = collectDatasets(grpInfo.Groups(ix), found);
end
end


function s = backoffSeconds(attempt)
% Small bounded exponential backoff: 0.05, 0.10, 0.20 ... <= 0.8 s.
s = min(0.8, 0.05 * 2^(max(0,attempt-1)));
end


function s = emptyPathDisplay(basePath)
if isempty(basePath)
    s = '/';
else
    s = basePath;
end
end
