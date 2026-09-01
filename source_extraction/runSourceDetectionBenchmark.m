function results = runSourceDetectionBenchmark(pathToTrialTable, commonParams, maxSynapseDensity)
%RUNSOURCEDETECTIONBENCHMARK Run native SILo and summarize_LoCo backends.
%
% Both runs use the same GIAnT preprocessing and refinement pipeline. SILo
% continues to write its normal experiment_summary.h5/per_trial_summary.h5;
% this wrapper snapshots those outputs after each run into backend-tagged
% copies, then restores the native SILo snapshots as the standard filenames.
%
% Example:
%   p = struct('isSLAP2',true,'drawUserRois',false,'nWorkers',8);
%   r = runSourceDetectionBenchmark('D:\session\trial_table.h5', p, 0.002);

arguments
    pathToTrialTable
    commonParams struct = struct()
    maxSynapseDensity (1,1) double {mustBePositive}
end

pathToTrialTable = char(pathToTrialTable);
[trialTablePath, savedr] = resolveBenchmarkPaths(pathToTrialTable);

pSilo = commonParams;
pSilo.sourceDetectionMethod = 'silo';

pLoco = commonParams;
pLoco.sourceDetectionMethod = 'summarize_loco';
pLoco.maxSynapseDensity = maxSynapseDensity;

results = struct();
results.pathToTrialTable = trialTablePath;
results.maxSynapseDensity = maxSynapseDensity;
results.outputDirectory = savedr;

fprintf('\n=== GIAnT source benchmark: native SILo ===\n');
t0 = tic;
paramsSilo = SILo(trialTablePath, pSilo);
results.siloSeconds = toc(t0);
snapshotStandardOutputs(savedr, 'silo');

fprintf('\n=== GIAnT source benchmark: summarize_LoCo-compatible detector ===\n');
t0 = tic;
paramsLoco = SILo(trialTablePath, pLoco);
results.summarizeLoCoSeconds = toc(t0);
snapshotStandardOutputs(savedr, 'summarize_loco');

% Restore the native SILo products to GIAnT's conventional filenames so a
% benchmark does not silently leave the alternative backend as the default
% downstream input.
copyfile(fullfile(savedr, 'experiment_summary_silo.h5'), ...
    fullfile(savedr, 'experiment_summary.h5'), 'f');
copyfile(fullfile(savedr, 'per_trial_summary_silo.h5'), ...
    fullfile(savedr, 'per_trial_summary.h5'), 'f');

% Also restore the trial-table analysis_params metadata to native SILo.
try
    tt = loadStructFromH5(trialTablePath);
    tt.source_extraction.analysis_params = paramsSilo;
    saveStructToH5(tt, trialTablePath);
catch ME
    warning('runSourceDetectionBenchmark:TrialTableRestoreFailed', ...
        'Could not restore native SILo analysis_params in trial table: %s', ME.message);
end

results.siloParams = paramsSilo;
results.summarizeLoCoParams = paramsLoco;
results.siloExperimentSummary = fullfile(savedr, 'experiment_summary_silo.h5');
results.siloPerTrialSummary = fullfile(savedr, 'per_trial_summary_silo.h5');
results.siloDiagnostics = fullfile(savedr, 'source_detection_diagnostics_silo.mat');
results.summarizeLoCoExperimentSummary = fullfile(savedr, 'experiment_summary_summarize_loco.h5');
results.summarizeLoCoPerTrialSummary = fullfile(savedr, 'per_trial_summary_summarize_loco.h5');
results.summarizeLoCoDiagnostics = fullfile(savedr, 'source_detection_diagnostics_summarize_loco.mat');

fprintf('\nBenchmark complete.\n');
fprintf('SILo: %.1f s\n', results.siloSeconds);
fprintf('summarize_LoCo: %.1f s\n', results.summarizeLoCoSeconds);
fprintf('Tagged outputs: %s\n', savedr);
fprintf('Standard GIAnT H5 outputs restored to the native SILo run.\n');
end

function [trialTablePath, savedr] = resolveBenchmarkPaths(pathIn)
if exist(pathIn, 'dir')
    trialTablePath = fullfile(pathIn, 'trial_table.h5');
else
    trialTablePath = pathIn;
end
assert(exist(trialTablePath, 'file') == 2, ...
    'Could not locate trial table: %s', trialTablePath);
try
    tt = loadStructFromH5(trialTablePath);
    savedr = fullfile(tt.savedr, 'source_extraction');
catch
    [ttDr,~,~] = fileparts(trialTablePath);
    savedr = fullfile(ttDr, 'source_extraction');
end
end

function snapshotStandardOutputs(savedr, tag)
for stem = {'experiment_summary','per_trial_summary'}
    src = fullfile(savedr, [stem{1} '.h5']);
    dst = fullfile(savedr, [stem{1} '_' tag '.h5']);
    assert(exist(src, 'file') == 2, ...
        'Expected SILo output was not created: %s', src);
    copyfile(src, dst, 'f');
end
end
