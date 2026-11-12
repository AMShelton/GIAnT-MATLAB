function [validTrials, qc] = selectValidTrials(corrCoeff, actValidPix, keepTrials, params)
%SELECTVALIDTRIALS Decide which trials enter source extraction after cross-trial alignment.
%
%   [validTrials, qc] = selectValidTrials(corrCoeff, actValidPix, keepTrials, params)
%
%   corrCoeff    1 x nTrials correlation of each trial's mean image with the
%                cross-trial template (NaN for trials that were not aligned).
%   actValidPix  1 x nTrials fraction of non-NaN pixels in each trial's aligned
%                activity image (pixels go NaN where frames were censored).
%   keepTrials   1 x nTrials logical from the trial table (pre-filter).
%   params       SILo parameters; fields used:
%       trialCorrRule   'absolute' (default) | 'outlier' | 'none'
%       minTrialCorr    absolute correlation floor (default 0.80)
%       trialCorrSigma  for 'outlier': number of std below the median (legacy 2)
%       trialCorrCap    for 'outlier': cap on the derived threshold (legacy 0.90)
%       minValidPixFrac fraction of the mean valid-pixel fraction a trial must
%                       reach (legacy 0.5)
%
%   'absolute' keeps every trial whose correlation is at least minTrialCorr;
%   'outlier' reproduces the historical GIAnT rule
%   min(trialCorrCap, median - trialCorrSigma*std); 'none' keeps every aligned
%   trial. The valid-pixel criterion applies under every rule.
%
%   qc records the per-trial values, the thresholds actually used and the
%   reason each excluded trial was dropped, and is saved with the experiment
%   summary (Path<n>/trial_qc) so the decision can be audited afterwards.

corrCoeff = double(corrCoeff(:)');
actValidPix = double(actValidPix(:)');
keepTrials = logical(keepTrials(:)');
nTrials = numel(corrCoeff);

rule = lower(char(string(getFieldOr(params, 'trialCorrRule', 'absolute'))));
minTrialCorr = getFieldOr(params, 'minTrialCorr', 0.80);
sigma = getFieldOr(params, 'trialCorrSigma', 2);
cap = getFieldOr(params, 'trialCorrCap', 0.90);
minValidPixFrac = getFieldOr(params, 'minValidPixFrac', 0.5);

switch rule
    case 'absolute'
        corrThresh = minTrialCorr;
    case 'outlier'
        corrThresh = min(cap, median(corrCoeff, 'omitnan') - sigma*std(corrCoeff, 'omitmissing'));
    case 'none'
        corrThresh = -Inf;
    otherwise
        error('selectValidTrials:InvalidRule', ...
            'trialCorrRule must be ''absolute'', ''outlier'' or ''none'' (got ''%s'').', rule);
end

validPixThresh = minValidPixFrac * mean(actValidPix(keepTrials & isfinite(actValidPix)), 'omitnan');
if ~isfinite(validPixThresh)
    validPixThresh = 0;
end

aligned = keepTrials & isfinite(corrCoeff);
passCorr = corrCoeff > corrThresh;
passPix = actValidPix > validPixThresh;
valid = aligned & passCorr & passPix;
validTrials = find(valid);

reason = repmat({''}, 1, nTrials);
for t = 1:nTrials
    if ~keepTrials(t)
        reason{t} = 'trial_table';
    elseif ~isfinite(corrCoeff(t))
        reason{t} = 'not_aligned';
    elseif ~passCorr(t) && ~passPix(t)
        reason{t} = 'low_corr_and_low_valid_pixels';
    elseif ~passCorr(t)
        reason{t} = 'low_corr';
    elseif ~passPix(t)
        reason{t} = 'low_valid_pixels';
    end
end

qc = struct();
qc.rule = rule;
qc.corrThresh = corrThresh;
qc.minTrialCorr = minTrialCorr;
qc.trialCorrSigma = sigma;
qc.trialCorrCap = cap;
qc.minValidPixFrac = minValidPixFrac;
qc.validPixThresh = validPixThresh;
qc.corrCoeff = corrCoeff;
qc.actValidPix = actValidPix;
qc.keepTrials = keepTrials;
qc.valid = valid;
qc.excludedTrials = find(keepTrials & ~valid);
qc.excludedReason = reason(qc.excludedTrials);
qc.corrMedian = median(corrCoeff(aligned), 'omitnan');
qc.corrStd = std(corrCoeff(aligned), 'omitmissing');
qc.corrMin = min(corrCoeff(aligned), [], 'omitnan');
% what the legacy rule would have done, for comparison
legacyThresh = min(0.90, median(corrCoeff, 'omitnan') - 2*std(corrCoeff, 'omitmissing'));
qc.legacyOutlierThresh = legacyThresh;
qc.nValidLegacyRule = sum(aligned & corrCoeff > legacyThresh & passPix);
end


function v = getFieldOr(s, name, default)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end
