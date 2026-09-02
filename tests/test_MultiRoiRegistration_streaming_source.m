function tests = test_MultiRoiRegistration_streaming_source
tests = functiontests(localfunctions);
end

function testH5SchemaIsPreflightedBeforeRegistration(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
txt = fileread(fullfile(root,'motion_correction','MultiRoiRegistration.m'));
preflightIx = strfind(txt,'precreateFinalAlignmentDatasets(partialAdataPath');
registerIx = strfind(txt,"disp('Registering:')");
verifyNotEmpty(testCase,preflightIx);
verifyNotEmpty(testCase,registerIx);
verifyLessThan(testCase,preflightIx(1),registerIx(1));
verifyTrue(testCase,contains(txt,"'/runtime/wall_s'"));
verifyTrue(testCase,contains(txt,'writeNumericDatasetRobust'));
verifyFalse(testCase,contains(txt,'function appendNumericDataset'));
end

function testIncompleteOutputPairCleanupPresent(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
txt = fileread(fullfile(root,'motion_correction','MultiRoiRegistration.m'));
verifyTrue(testCase,contains(txt,'cleanupIncompleteOutputPair'));
verifyTrue(testCase,contains(txt,'partialAdataPath'));
verifyTrue(testCase,contains(txt,'movefile(partialAdataPath, adataPath'));
end
