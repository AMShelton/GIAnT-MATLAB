classdef MockLineHeaderFileBatch < handle
    properties
        lineHeaderIdxs = 1:4
        numCycles = 6
        vectorCalls = 0
        scalarCalls = 0
    end
    methods
        function headers = getLineHeader(obj,resIdxs,cycleIdxs)
            if numel(resIdxs)>1
                obj.vectorCalls = obj.vectorCalls + 1;
            else
                obj.scalarCalls = obj.scalarCalls + 1;
            end
            if isscalar(cycleIdxs)
                cycleIdxs = repmat(cycleIdxs,size(resIdxs));
            end
            if numel(resIdxs) ~= numel(cycleIdxs)
                error('MockLineHeaderFileBatch:SizeMismatch','Inputs must match.');
            end
            headers = repmat(struct('xOffset_pix',0,'yOffset_pix',0,'zOffset_um',0),size(resIdxs));
            for ix = 1:numel(resIdxs)
                r = double(resIdxs(ix)); c = double(cycleIdxs(ix));
                headers(ix) = struct('xOffset_pix',r+1000*c, ...
                    'yOffset_pix',-r+10*c,'zOffset_um',0.5*c);
            end
        end
    end
end
