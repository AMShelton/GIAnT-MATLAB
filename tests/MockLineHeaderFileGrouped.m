classdef MockLineHeaderFileGrouped < handle
    properties
        lineHeaderIdxs = 1:4
        numCycles = 6
        groupedCalls = 0
    end
    methods
        function headers = getLineHeader(obj,resIdxs,cycleIdxs)
            if ~isscalar(cycleIdxs)
                error('MockLineHeaderFileGrouped:ScalarCycleOnly','cycleIdx must be scalar.');
            end
            obj.groupedCalls = obj.groupedCalls + 1;
            headers = repmat(struct('xOffset_pix',0,'yOffset_pix',0,'zOffset_um',0),size(resIdxs));
            for ix = 1:numel(resIdxs)
                r = double(resIdxs(ix)); c = double(cycleIdxs);
                headers(ix) = struct('xOffset_pix',r+1000*c, ...
                    'yOffset_pix',-r+10*c,'zOffset_um',0.5*c);
            end
        end
    end
end
