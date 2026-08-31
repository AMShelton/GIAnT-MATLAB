function tests = test_getCachedSlap2Resources_source
% Static regression guard: the helper must preserve a no-cache fallback.
tests = functiontests(localfunctions);
end

function testFallbackAndClearArePresent(testCase)
fn = which('getCachedSlap2Resources');
verifyNotEmpty(testCase,fn);
txt = fileread(fn);
verifyTrue(testCase,contains(txt,'slap2.Slap2DataFile(fullPath)'));
verifyTrue(testCase,contains(txt,'loadMetadata(fullPath)'));
verifyTrue(testCase,contains(txt,'strcmp(action,''clear'')'));
end
