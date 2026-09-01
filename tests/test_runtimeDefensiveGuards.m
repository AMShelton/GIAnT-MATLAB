function tests = test_runtimeDefensiveGuards
tests = functiontests(localfunctions);
end

function testDefensiveMarkersPresent(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
checks = {
    fullfile('dependencies','extraction','processAllTrials_Async.m'), 'GIAnT:NaNFillFailed'
    fullfile('dependencies','extraction','processAllTrials_Async.m'), 'GIAnT:NoValidFreshness'
    fullfile('motion_correction','MultiRoiRegistration.m'), 'lastReaderError'
    fullfile('motion_correction','MultiRoiRegistration.m'), 'MultiRoiRegistration:NoRasterPixels'
    fullfile('source_extraction','SILo.m'), 'SILo:NoValidAlignedTrials'
    fullfile('dependencies','extraction','extractTrial.m'), 'extractTrial:InvalidPhotonScale'
    fullfile('dependencies','extraction','activityImage','getActImPeaks.m'), 'sigma_bg <= 0'
    fullfile('dependencies','gui','setParams.m'), 'logicalScalar'
    };
for k = 1:size(checks,1)
    txt = fileread(fullfile(root,checks{k,1}));
    verifyTrue(testCase,contains(txt,checks{k,2}), ...
        sprintf('Missing defensive runtime marker %s in %s',checks{k,2},checks{k,1}));
end
end

function testLegacyNumericLogicalPresetsNormalize(testCase)
p = setParams('MultiRoiRegistration',struct( ...
    'overwriteExisting',int64(0), ...
    'refStackTemplate',int64(0), ...
    'isReVolt',int64(0), ...
    'includeIntegrationROIs',int64(0)));
verifyTrue(testCase,islogical(p.overwriteExisting));
verifyFalse(testCase,p.overwriteExisting);

p = setParams('SILo',struct( ...
    'isSLAP2',int64(1), ...
    'drawUserRois',int64(0), ...
    'includeIntegrationROIs',int64(0), ...
    'savePerTrialSummary',int64(0)));
verifyTrue(testCase,islogical(p.isSLAP2));
verifyTrue(testCase,p.isSLAP2);
verifyFalse(testCase,p.drawUserRois);
verifyFalse(testCase,p.savePerTrialSummary);
end
