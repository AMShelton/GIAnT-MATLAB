classdef MockLineHeaderFileScalar < handle
    properties
        lineHeaderIdxs = 1:4
        numCycles = 6
        scalarCalls = 0
    end
    methods
        function header = getLineHeader(obj,resIdx,cycleIdx)
            if ~isscalar(resIdx) || ~isscalar(cycleIdx)
                error('MockLineHeaderFileScalar:ScalarOnly','Only scalar requests are supported.');
            end
            obj.scalarCalls = obj.scalarCalls + 1;
            header = struct( ...
                'xOffset_pix',double(resIdx) + 1000*double(cycleIdx), ...
                'yOffset_pix',-double(resIdx) + 10*double(cycleIdx), ...
                'zOffset_um',0.5*double(cycleIdx));
        end
    end
end
