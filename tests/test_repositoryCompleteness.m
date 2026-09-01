function tests = test_repositoryCompleteness
% Regression guard that the optimized GIAnT checkout is internally complete.
tests = functiontests(localfunctions);
end

function testRequiredOptimizedFilesPresent(testCase)
root = fileparts(fileparts(mfilename('fullpath')));

required = {
    'processSLAP2.m'
    'buildTrialTableSLAP2.m'
    fullfile('source_extraction','SILo.m')
    fullfile('motion_correction','MultiRoiRegistration.m')
    fullfile('dependencies','gui','setParams.m')
    fullfile('dependencies','gui','optionsGUI.m')
    fullfile('dependencies','extraction','extractTrial.m')
    fullfile('dependencies','extraction','processAllTrials_Async.m')
    fullfile('dependencies','extraction','getCachedSlap2Resources.m')
    fullfile('dependencies','extraction','activityImage','getActImPeaks.m')
    fullfile('dependencies','alignment','interpFramesSelected.m')
    fullfile('dependencies','alignment','interpFramesSelectedBatch.m')
    fullfile('dependencies','alignment','interpFrameTranslationChannels.m')
    fullfile('dependencies','alignment','xcorr2_nans_weighted_fast.m')
    };

for k = 1:numel(required)
    fn = fullfile(root,required{k});
    verifyTrue(testCase,isfile(fn),sprintf('Missing optimized GIAnT file: %s',required{k}));
end
end

function testLatestOptimizationMarkersPresent(testCase)
root = fileparts(fileparts(mfilename('fullpath')));

checks = {
    fullfile('buildTrialTableSLAP2.m'), 'dynamic_data'
    fullfile('motion_correction','MultiRoiRegistration.m'), 'registrationBlockFrames'
    fullfile('motion_correction','MultiRoiRegistration.m'), 'xcorr2_nans_weighted_fast'
    fullfile('dependencies','gui','setParams.m'), 'solverRobustFallback'
    fullfile('dependencies','gui','setParams.m'), 'useFastWeightedXcorr'
    fullfile('dependencies','gui','optionsGUI.m'), 'coercePresetValue'
    fullfile('dependencies','extraction','extractTrial.m'), 'fminconTrustRegionRobust'
    fullfile('dependencies','extraction','processAllTrials_Async.m'), 'interpFramesSelectedBatch'
    fullfile('dependencies','extraction','activityImage','getActImPeaks.m'), 'actIM = double(actIM)'
    };

for k = 1:size(checks,1)
    fn = fullfile(root,checks{k,1});
    txt = fileread(fn);
    verifyTrue(testCase,contains(txt,checks{k,2}), ...
        sprintf('File is not the expected optimized revision: %s (missing marker "%s")', ...
        checks{k,1},checks{k,2}));
end
end
