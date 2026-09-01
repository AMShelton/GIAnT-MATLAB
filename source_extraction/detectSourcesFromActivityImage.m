function [sources, detectionIM, info] = detectSourcesFromActivityImage(rawActIM, nanFrac, somaMask, params)
%DETECTSOURCESFROMACTIVITYIMAGE Select source seeds using SILo or summarize_LoCo logic.
%
% This helper isolates source-seed detection from the rest of SILo so that
% identical registered movies, trial-local activity images, cross-trial
% alignment, valid-trial selection, source neighborhoods, and downstream
% refinement can be benchmarked with different source-detection rules.
%
% Required params:
%   sourceDetectionMethod : 'silo' (default) or 'summarize_loco'
%   nanThresh             : existing SILo invalid-pixel threshold
%   dXY                   : existing source scale
%
% summarize_LoCo additionally requires:
%   maxSynapseDensity     : same value used by the original summarize_LoCo
%
% Outputs:
%   sources.R/C/V         : one-indexed source seed rows/cols/activity values
%   detectionIM           : exact backend-specific image passed to peak selection
%   info                  : compact diagnostic information for benchmarking

if ~isfield(params, 'sourceDetectionMethod') || isempty(params.sourceDetectionMethod)
    method = 'silo';
else
    method = lower(strrep(char(params.sourceDetectionMethod), '-', '_'));
end
if any(strcmp(method, {'summarizeloco','loco'}))
    method = 'summarize_loco';
end

rawActIM = squeeze(rawActIM);
nanFrac = squeeze(nanFrac);
somaMask = logical(squeeze(somaMask));

sources = struct('R', [], 'C', [], 'V', []);
info = struct( ...
    'method', method, ...
    'threshold', nan, ...
    'totalValidPixels', 0, ...
    'nCandidatesBeforeThreshold', 0, ...
    'medianFilterSize', [], ...
    'activityStatistic', 'mean_aligned_valid_trials_includenan');

switch method
    case 'silo'
        % IMPORTANT: keep this block mathematically identical to the current
        % SILo.m source-selection path. Do not "improve" the normalization
        % here; SILo is the control arm of the benchmark.
        detectionIM = rawActIM;
        detectionIM = detectionIM ./ 10^(floor(log10(max(detectionIM(:))))-1);
        detectionIM(nanFrac > params.nanThresh) = nan;
        info.medianFilterSize = [5 5];
        medIM = nanmedfilt2(detectionIM, 5.*[1 1]);
        detectionIM = detectionIM - medIM;

        thetaf = getActImPeaks(detectionIM, params.peakth, somaMask, params.minPeakDistance);
        info.totalValidPixels = sum(~isnan(detectionIM(:)) & ~somaMask(:));

        if info.totalValidPixels == 0 || isempty(thetaf)
            return
        end

        sources.R = round(thetaf(:,2));
        sources.C = round(thetaf(:,3));
        sources.V = thetaf(:,1);

        % Preserve current SILo duplicate-coordinate pruning.
        [~, uniqueIx] = unique([sources.R(:) sources.C(:)], 'rows', 'stable');
        sources.R = sources.R(uniqueIx);
        sources.C = sources.C(uniqueIx);
        sources.V = sources.V(uniqueIx);

    case 'summarize_loco'
        if ~isfield(params, 'maxSynapseDensity') || isempty(params.maxSynapseDensity) || ...
                ~isscalar(params.maxSynapseDensity) || ~isfinite(params.maxSynapseDensity) || ...
                params.maxSynapseDensity <= 0
            error('SILo:MissingMaxSynapseDensity', ...
                ['sourceDetectionMethod="summarize_loco" requires maxSynapseDensity. ' ...
                 'Use the value from the original summarize_LoCo parameter set.']);
        end
        if ~isfield(params, 'dXY') || isempty(params.dXY) || ...
                ~isscalar(params.dXY) || ~isfinite(params.dXY) || params.dXY <= 0
            error('SILo:MissingDXY', 'summarize_LoCo backend requires a positive params.dXY.');
        end

        % Preserve summarize_LoCo source selection:
        % mean aligned activity image -> dXY-scaled local median subtraction
        % -> positive 3x3 local maxima -> iterative 5x5 suppression -> soma
        % exclusion -> maximum-source-density amplitude threshold.
        filterSide = 2*ceil(1.5*params.dXY)+1;
        info.medianFilterSize = [filterSide filterSide];

        medIM = nanmedfilt2(rawActIM, filterSide.*[1 1]);
        detectionIM = rawActIM - medIM;

        explored = detectionIM;
        pTmp = explored > 0 & explored == ordfilt2(explored, 9, ones(3));
        pIM = false(size(detectionIM));

        while any(pTmp(:))
            pIM = pIM | pTmp;
            explored(imdilate(pTmp, ones(5))) = 0;
            pTmp = explored > 0 & explored == ordfilt2(explored, 9, ones(3));
        end

        pIM(somaMask) = 0;
        p = detectionIM(pIM);

        info.nCandidatesBeforeThreshold = numel(p);
        info.totalValidPixels = sum(~isnan(detectionIM(:)) & ~somaMask(:));

        if info.totalValidPixels == 0 || isempty(p)
            return
        end

        densityIx = min(numel(p), ceil(info.totalValidPixels * params.maxSynapseDensity));
        densityIx = max(1, densityIx);

        % Exact kth-largest threshold from summarize_LoCo without sorting the
        % entire candidate vector when k is small relative to candidate count.
        if densityIx < numel(p)
            topP = maxk(p, densityIx);
            densityPeak = min(topP);
        else
            densityPeak = min(p);
        end
        info.threshold = 2 * densityPeak;

        pp = detectionIM;
        pp(~pIM) = 0;
        pp(pp < info.threshold) = 0;
        [sources.R, sources.C, sources.V] = find(pp);

    otherwise
        error('SILo:UnknownSourceDetectionMethod', ...
            'Unknown sourceDetectionMethod "%s". Use "silo" or "summarize_loco".', method);
end
end
