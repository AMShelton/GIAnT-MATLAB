function lt = loadLookupTableH5(filename)
%LOADLOOKUPTABLEH5 Read integration registration lookup table from HDF5.
lt = lookupTableFromH5Struct(loadStructFromH5(filename));
end


function lt = lookupTableFromH5Struct(s)
%LOOKUPTABLEFROMH5STRUCT Rebuild cell-array lookup table from H5 struct.
lt = struct();
lt.xPre = s.xPre;
lt.xPost = s.xPost;
lt.yPre = s.yPre;
lt.yPost = s.yPost;

pathNames = fieldnames(s);
pathNames = pathNames(startsWith(pathNames, 'Path'));
if isempty(pathNames)
    error('loadLookupTableH5:MissingPaths', 'No Path{N} groups found in lookup table H5.');
end

pathNums = nan(size(pathNames));
for ix = 1:numel(pathNames)
    pathNums(ix) = sscanf(pathNames{ix}, 'Path%d', 1);
end
[~, order] = sort(pathNums);
pathNames = pathNames(order);

nDMD = numel(pathNames);
lt.likelihood_means = cell(1, nDMD);
lt.allSuperPixelIDs = cell(1, nDMD);
lt.sparseMaskInds = cell(1, nDMD);
lt.zPre = cell(1, nDMD);
lt.zPost = cell(1, nDMD);
lt.fastZ2RefZ = cell(1, nDMD);

for d = 1:nDMD
    p = s.(pathNames{d});
    lt.likelihood_means{d} = p.likelihood_means;
    lt.allSuperPixelIDs{d} = p.allSuperPixelIDs;
    lt.sparseMaskInds{d} = p.sparseMaskInds;
    lt.zPre{d} = p.zPre;
    lt.zPost{d} = p.zPost;
    lt.fastZ2RefZ{d} = p.fastZ2RefZ;
end
end
