function test_saveStructToH5_lowlevel(outDir)
%TEST_SAVESTRUCTTOH5_LOWLEVEL Schema + round-trip check for saveStructToH5.
%   test_saveStructToH5_lowlevel()          writes to tempdir
%   test_saveStructToH5_lowlevel(outDir)    writes to outDir (point this at
%                                           a VAST/SMB folder to exercise the
%                                           real storage path)
%
%   1. Writes a representative struct (trial-table-like strings, a 2-D
%      filename grid, every numeric class, logical, nested groups) with
%      saveStructToH5 and reads it back with loadStructFromH5.
%   2. Writes the same datasets with the high-level h5create/h5write
%      functions (the previous implementation) to a second file and asserts
%      h5info reports identical Dataspace.Size, Datatype.Class/Type/Size and
%      ChunkSize/Layout for every dataset, i.e. the on-disk schema is
%      unchanged for every reader (MATLAB, h5py, SILo, Python pipeline).

if nargin < 1 || isempty(outDir)
    outDir = tempdir;
end
fnNew = fullfile(outDir, ['saveStructToH5_lowlevel_' char(java.util.UUID.randomUUID()) '.h5']);
fnRef = fullfile(outDir, ['saveStructToH5_reference_' char(java.util.UUID.randomUUID()) '.h5']);
cleanup = onCleanup(@() deleteQuiet({fnNew, fnRef}));

% ---- representative struct ------------------------------------------------
s = struct();
s.datadr = 'Z:\some\data\dir';                      % char -> [1 1] string
s.savedr = "Z:\some\save\dir";                       % scalar string
s.filename = {'a.dat','b.dat','c.dat'; 'd.dat','','f.dat'}; % 2-D cell w/ empty
s.tags = ["x" "y" "z"];                              % string row
s.epoch = int32([1 1 2; 1 1 2]);
s.flag = true;
s.mask = logical([1 0 1 1]);
s.numChannels = 2;
s.frametime = single(1/30);
s.DSframes = uint32(1:100);
s.big = int64([-5 7]);
s.ubig = uint64([5 7]);
s.i8 = int8(-3); s.u8 = uint8(200); s.i16 = int16(-300); s.u16 = uint16(60000);
s.slap2 = struct();
s.slap2.Z_depths = [10.5; 20.5];
s.slap2.cropRow = -8;
s.slap2.viewC = 1:0.5:50;
s.slap2.viewR = (1:0.5:50)';
s.slap2.nested.deeper.value = rand(3,4,2);
s.emptyNumeric = [];                                 % skipped
s.emptyCell = {};                                    % skipped

% ---- 1. new implementation + round trip ---------------------------------
saveStructToH5(s, fnNew);
r = loadStructFromH5(fnNew);

assert(strcmp(r.datadr, s.datadr), 'datadr round trip');
assert(strcmp(r.savedr, char(s.savedr)), 'savedr round trip');
assert(isequal(r.filename, s.filename), 'filename grid round trip (2-D cell incl. empty)');
assert(isequal(r.tags, cellstr(s.tags)), 'string array round trip');
assert(isequal(r.epoch, s.epoch) && isa(r.epoch,'int32'), 'int32 round trip');
assert(isequal(r.flag, int8(1)), 'logical scalar -> int8');
assert(isequal(r.mask, int8(s.mask)), 'logical array -> int8');
assert(isequal(r.frametime, s.frametime) && isa(r.frametime,'single'), 'single round trip');
assert(isequal(r.DSframes, s.DSframes) && isa(r.DSframes,'uint32'), 'uint32 round trip');
assert(isequal(r.big, s.big) && isa(r.big,'int64'), 'int64 round trip');
assert(isequal(r.ubig, s.ubig) && isa(r.ubig,'uint64'), 'uint64 round trip');
assert(isequal(r.i8, s.i8) && isequal(r.u8, s.u8) && isequal(r.i16, s.i16) && isequal(r.u16, s.u16), 'small ints');
assert(isequal(r.slap2.Z_depths, s.slap2.Z_depths), 'column vector');
assert(isequal(r.slap2.viewC, s.slap2.viewC) && isequal(r.slap2.viewR, s.slap2.viewR), 'viewC/viewR');
assert(isequal(r.slap2.nested.deeper.value, s.slap2.nested.deeper.value), '3-D nested');
assert(~isfield(r, 'emptyNumeric') && ~isfield(r, 'emptyCell'), 'empties skipped');
assert(isequal(h5read(fnNew, '/row_major'), uint8(0)), 'row_major flag');

% ---- 2. schema identity vs. high-level h5create/h5write ------------------
if exist(fnRef, 'file'), delete(fnRef); end
writeReference(fnRef, '', s);
h5create(fnRef, '/row_major', [1 1], 'Datatype', 'uint8');
h5write(fnRef, '/row_major', uint8(0));

newDs = flattenInfo(h5info(fnNew), containers.Map());
refDs = flattenInfo(h5info(fnRef), containers.Map());
assert(isequal(sort(newDs.keys), sort(refDs.keys)), 'same set of dataset paths');
paths = newDs.keys;
for ix = 1:numel(paths)
    a = newDs(paths{ix}); b = refDs(paths{ix});
    assert(isequal(a.Dataspace.Size, b.Dataspace.Size), 'size differs at %s', paths{ix});
    assert(strcmp(a.Datatype.Class, b.Datatype.Class), 'type class differs at %s', paths{ix});
    assert(isequal(a.Datatype.Type, b.Datatype.Type), 'type differs at %s: %s vs %s', ...
        paths{ix}, describeType(a.Datatype.Type), describeType(b.Datatype.Type));
    assert(isequal(a.Datatype.Size, b.Datatype.Size), 'type size differs at %s', paths{ix});
    assert(isequal(a.ChunkSize, b.ChunkSize), 'layout differs at %s', paths{ix});
end

fprintf('test_saveStructToH5_lowlevel: PASS (%d datasets, %s)\n', numel(paths), outDir);
end


function writeReference(filename, basePath, s)
% Previous implementation's mapping, using the high-level functions.
f = fieldnames(s);
for ix = 1:numel(f)
    path = [basePath '/' f{ix}];
    v = s.(f{ix});
    if isstruct(v)
        writeReference(filename, path, v);
    elseif iscell(v)
        if isempty(v), continue; end
        sv = strings(size(v));
        for k = 1:numel(v)
            if ~isempty(v{k}), sv(k) = string(v{k}); end
        end
        h5create(filename, path, size(sv), 'Datatype', 'string'); h5write(filename, path, sv);
    elseif ischar(v)
        h5create(filename, path, [1 1], 'Datatype', 'string'); h5write(filename, path, string(v));
    elseif isstring(v)
        sz = size(v); if isscalar(v), sz = [1 1]; end
        h5create(filename, path, sz, 'Datatype', 'string'); h5write(filename, path, v);
    elseif islogical(v)
        if isempty(v), continue; end
        h5create(filename, path, size(v), 'Datatype', 'int8'); h5write(filename, path, int8(v));
    elseif isnumeric(v)
        if isempty(v), continue; end
        h5create(filename, path, size(v), 'Datatype', class(v)); h5write(filename, path, v);
    end
end
end


function m = flattenInfo(g, m)
for ix = 1:numel(g.Datasets)
    if strcmp(g.Name, '/'), p = ['/' g.Datasets(ix).Name]; else, p = [g.Name '/' g.Datasets(ix).Name]; end
    m(p) = g.Datasets(ix);
end
for ix = 1:numel(g.Groups)
    m = flattenInfo(g.Groups(ix), m);
end
end


function str = describeType(t)
if ischar(t), str = t; elseif isstruct(t), str = jsonencode(t); else, str = class(t); end
end


function deleteQuiet(files)
for ix = 1:numel(files)
    try
        if exist(files{ix}, 'file'), delete(files{ix}); end
    catch
    end
end
end
