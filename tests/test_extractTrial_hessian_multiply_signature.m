function tests = test_extractTrial_hessian_multiply_signature
tests = functiontests(localfunctions);
end

function testTrustRegionHessianMultiplyUsesTwoInputs(testCase)
fn = which('extractTrial');
verifyNotEmpty(testCase,fn);
txt = fileread(fn);

verifyFalse(testCase,contains(txt,'@(hinfo, v, flag)'));
verifyFalse(testCase,contains(txt,'@(Hinfo, v, flag)'));
verifyFalse(testCase,contains(txt,'@(Hinfo,v,flag)'));
verifyTrue(testCase,contains(txt,'optsRetry.HessianMultiplyFcn = @(Hinfo,v)'));
verifyTrue(testCase,contains(txt,'Hv = baseHM(Hinfo,v);'));
end
