function saveLookupTableH5(lt, filename)
%SAVELOOKUPTABLEH5 Write band registration lookup table to HDF5.
%   Schema: /xPre, /xPost, /yPre, /yPost; /Path{N}/likelihood_means, ...
saveStructToH5(lookupTableToH5Struct(lt), filename);
end


function s = lookupTableToH5Struct(lt)
%LOOKUPTABLETOH5STRUCT Map cell-array lookup table to Path{N} groups for H5.
s = struct();
s.xPre = lt.xPre;
s.xPost = lt.xPost;
s.yPre = lt.yPre;
s.yPost = lt.yPost;

nDMD = numel(lt.likelihood_means);
for d = 1:nDMD
    pathName = sprintf('Path%d', d);
    s.(pathName) = struct( ...
        'likelihood_means', lt.likelihood_means{d}, ...
        'allSuperPixelIDs', lt.allSuperPixelIDs{d}, ...
        'sparseMaskInds', lt.sparseMaskInds{d}, ...
        'zPre', lt.zPre{d}, ...
        'zPost', lt.zPost{d}, ...
        'fastZ2RefZ', lt.fastZ2RefZ{d});
end
end
