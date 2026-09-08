function tests = test_solverRobustness_source
% Static regression guards for rare Optimization Toolbox solver fallbacks.
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
verifyTrue(testCase,contains(txt,'fminconInteriorPointFallback'));
verifyTrue(testCase,contains(txt,"'HessianApproximation','lbfgs'"));
verifyTrue(testCase,contains(txt,'validateFallbackSolution'));
end

function testFallbackIsErrorTriggeredOnly(testCase)
fn = which('extractTrial');
txt = fileread(fn);

% The normal first call must remain an ordinary trust-region fmincon solve
% before any damping or alternate solver is introduced.
verifyTrue(testCase,contains(txt, ...
    '[x,fval] = fmincon(fun,x0,[],[],[],[],lb,ub,[],opts);'));
verifyTrue(testCase,contains(txt, ...
    'if ~isTrdogQuad1dError(ME) || ~logical(params.solverRobustFallback)'));

% The alternate algorithm must occur only inside the robust wrapper, after
% trust-region retries have been exhausted.
ixRetry = strfind(txt,'GIAnT solver trust-region retries exhausted');
ixIP = strfind(txt,'fminconInteriorPointFallback(fun,x0,lb,ub,opts)');
verifyNotEmpty(testCase,ixRetry);
verifyNotEmpty(testCase,ixIP);
verifyGreaterThan(testCase,ixIP(1),ixRetry(1));
end

function testInteriorPointFallbackPreservesProblemAndGuardsOutput(testCase)
fn = which('extractTrial');
txt = fileread(fn);

verifyTrue(testCase,contains(txt,"'Algorithm','interior-point'"));
verifyTrue(testCase,contains(txt,"'SpecifyObjectiveGradient',true"));
verifyTrue(testCase,contains(txt,"'HessianApproximation','lbfgs'"));
verifyTrue(testCase,contains(txt, ...
    '[x,fval,exitflag] = fmincon(fun,x0,[],[],[],[],lb,ub,[],optsIP);'));
verifyTrue(testCase,contains(txt,'GIAnT:InvalidSolverFallbackResult'));
end

function testBaselineLeastSquaresPinnedToInteriorPoint(testCase)
fn = which('extractTrial');
txt = fileread(fn);

% fitB is a convex bounded linear least-squares problem. Pin it explicitly
% to MATLAB's interior-point lsqlin backend so this baseline stage cannot
% drift into the trdog trust-region implementation.
verifyTrue(testCase,contains(txt, ...
    "opts = optimoptions('lsqlin','Algorithm','interior-point','Display','none');"));
end
