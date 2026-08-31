function tests = test_extractTrial_fmincon_precision
% Regression guard for MATLAB R2024b fmincon double-output requirement.
tests = functiontests(localfunctions);
end

function testExtractTrialSourceContainsDoubleHessianCache(testCase)
fn = which('extractTrial');
verifyNotEmpty(testCase, fn);
txt = fileread(fn);

% The cached Hessian state must be returned as a raw double numeric array,
% not a struct such as Hinfo.coef, because fmincon validates every objective
% output as double before the first iteration.
verifyTrue(testCase, contains(txt, ...
    'Hinfo = double(2.*(Z+1).^2./(F.*(s.^3)))'));
verifyFalse(testCase, contains(txt, 'Hinfo.coef ='));
end
