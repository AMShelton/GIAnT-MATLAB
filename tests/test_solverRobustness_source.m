function tests = test_solverRobustness_source
% Static regression guard for the rare trdog/quad1d fallback pathway.
tests = functiontests(localfunctions);
end

function testRobustWrapperPresent(testCase)
fn = which('extractTrial');
verifyNotEmpty(testCase,fn);
txt = fileread(fn);

verifyTrue(testCase,contains(txt,'fminconTrustRegionRobust'));
verifyTrue(testCase,contains(txt,'Square root error in trdog/quad1d'));
verifyTrue(testCase,contains(txt,'dampedHessianMultiply'));
verifyTrue(testCase,contains(txt,'solverRetryDamping'));
end

function testFallbackIsErrorTriggeredOnly(testCase)
fn = which('extractTrial');
txt = fileread(fn);

% The normal first call must remain an ordinary fmincon solve before any
% damping is introduced.
verifyTrue(testCase,contains(txt, ...
    '[x,fval] = fmincon(fun,x0,[],[],[],[],lb,ub,[],opts);'));
verifyTrue(testCase,contains(txt, ...
    'if ~isTrdogQuad1dError(ME) || ~logical(params.solverRobustFallback)'));
end
