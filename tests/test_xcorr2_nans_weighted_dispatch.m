function tests = test_xcorr2_nans_weighted_dispatch
%TEST_XCORR2_NANS_WEIGHTED_DISPATCH Regression tests for safe xcorr dispatch.
tests = functiontests(localfunctions);
end

function testExactFallbackMatchesCurrentFast(testCase)
rng(21);
frame = randn(43,51);
template = randn(43,51);
freshness = 0.2 + 3*rand(43,51);
frame(rand(size(frame))<0.13) = nan;
template(rand(size(template))<0.09) = nan;
opts = struct('useMex',false,'useAdaptive',false);

[mRef,rRef,cRef] = xcorr2_nans_weighted_fast( ...
    frame,freshness,template,[0;0],5);
[mGot,rGot,cGot,info] = xcorr2_nans_weighted_dispatch( ...
    frame,freshness,template,[0;0],5,opts);

verifyEqual(testCase,mGot,mRef,'AbsTol',0);
verifyEqual(testCase,rGot,rRef,'AbsTol',0);
verifyEqual(testCase,cGot,cRef,'AbsTol',0);
verifyEqual(testCase,info.backend,'matlab-fast');
verifyEqual(testCase,info.usedRadius,5);
verifyEqual(testCase,info.mexAttempts,0);
verifyEqual(testCase,info.mexSuccesses,0);
verifyEqual(testCase,info.matlabFastCalls,1);
verifyEqual(testCase,info.mexFallbacks,0);
verifyFalse(testCase,info.mexRequested);
verifyEqual(testCase,info.frameClass,'double');
verifyEqual(testCase,info.freshnessClass,'double');
verifyEqual(testCase,info.templateClass,'double');
end

function testAdaptiveBoundaryExpandsToExactFullSearch(testCase)
% Construct a translated image whose best residual is outside +/-2 so the
% adaptive small-radius peak must hit a boundary and expand to +/-5.
rng(22);
template = rand(55,63);
frame = circshift(template,[0 4]);
freshness = ones(size(frame));
% Remove wrapped regions so circular content cannot create an artificial
% alternative optimum.
frame(:,1:4) = nan;
template(rand(size(template))<0.03) = nan;
opts = struct('useMex',false,'useAdaptive',true, ...
    'adaptiveRadius',2,'adaptiveAuditEvery',1000, ...
    'adaptiveMinCorrelation',-1);

[mRef,rRef,cRef] = xcorr2_nans_weighted_fast( ...
    frame,freshness,template,[0;0],5);
[mGot,rGot,cGot,info] = xcorr2_nans_weighted_dispatch( ...
    frame,freshness,template,[0;0],5,opts);

verifyEqual(testCase,mGot,mRef,'AbsTol',1e-12);
verifyEqual(testCase,rGot,rRef,'AbsTol',1e-12);
verifyEqual(testCase,cGot,cRef,'AbsTol',1e-12);
verifyTrue(testCase,info.expandedToFull);
verifyEqual(testCase,info.usedRadius,5);
end

function testBackendDiagnosticsFieldsPresent(testCase)
rng(210);
frame = randn(19,23);
template = randn(19,23);
freshness = 0.5 + rand(19,23);
opts = struct('useMex',false,'useAdaptive',false);
[~,~,~,info] = xcorr2_nans_weighted_dispatch( ...
    frame,freshness,template,[0;0],3,opts);
expected = {'backend','mexRequested','mexInputCompatible', ...
    'mexValidationRequested','mexValidationPassed', ...
    'frameClass','freshnessClass','templateClass', ...
    'mexAttempts','mexSuccesses','matlabFastCalls','mexFallbacks'};
for k = 1:numel(expected)
    verifyTrue(testCase,isfield(info,expected{k}), ...
        sprintf('Missing diagnostics field: %s',expected{k}));
end
verifyEqual(testCase,info.matlabFastCalls,1);
end


function testSingleInputsAreMexCompatibleWhenBinaryExists(testCase)
assumeTrue(testCase,exist('xcorr2_nans_weighted_mex','file') == 3, ...
    'Optional MEX binary is not built on this machine.');
rng(211);
frame = single(randn(23,29));
freshness = single(0.25 + rand(23,29));
template = double(randn(23,29));
frame(rand(size(frame))<0.1) = nan;
template(rand(size(template))<0.1) = nan;
opts = struct('useMex',true,'validateMexOnFirstUse',true,'useAdaptive',false);
[~,~,~,info] = xcorr2_nans_weighted_dispatch( ...
    frame,freshness,template,[0;0],3,opts);
verifyTrue(testCase,info.mexInputCompatible);
verifyEqual(testCase,info.backend,'mex');
verifyEqual(testCase,info.mexAttempts,1);
verifyEqual(testCase,info.mexSuccesses,1);
verifyEqual(testCase,info.matlabFastCalls,0);
verifyEqual(testCase,info.mexFallbacks,0);
end

function testMixedPrecisionSignatureGetsIndependentValidation(testCase)
assumeTrue(testCase,exist('xcorr2_nans_weighted_mex','file') == 3, ...
    'Optional MEX binary is not built on this machine.');
% Clear persistent dispatcher state so this test exercises both signatures.
clear xcorr2_nans_weighted_dispatch
rng(212);
frame = single(randn(21,27));
freshness = single(0.2 + rand(21,27));
templateS = single(randn(21,27));
templateD = double(templateS);
opts = struct('useMex',true,'validateMexOnFirstUse',true,'useAdaptive',false);
[~,~,~,infoS] = xcorr2_nans_weighted_dispatch(frame,freshness,templateS,[0;0],2,opts);
[~,~,~,infoD] = xcorr2_nans_weighted_dispatch(frame,freshness,templateD,[0;0],2,opts);
verifyEqual(testCase,infoS.backend,'mex');
verifyTrue(testCase,infoS.mexValidationPassed);
verifyEqual(testCase,infoD.backend,'mex');
verifyTrue(testCase,infoD.mexValidationPassed);
end

function testProductionSourceNeverCompilesMex(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
multiTxt = fileread(fullfile(root,'motion_correction','MultiRoiRegistration.m'));
dispatchTxt = fileread(fullfile(root,'dependencies','alignment', ...
    'xcorr2_nans_weighted_dispatch.m'));

% Guard against either direct compiler invocation or routing production code
% through the explicit build helper.  Do NOT search for the raw substring
% "mex(" because that incorrectly matches the intended backend function name
% xcorr2_nans_weighted_mex(...).
verifyFalse(testCase,containsCompilerInvocation(multiTxt));
verifyFalse(testCase,containsCompilerInvocation(dispatchTxt));
verifyFalse(testCase,containsBuildHelperInvocation(multiTxt));
verifyFalse(testCase,containsBuildHelperInvocation(dispatchTxt));

verifyTrue(testCase,contains(dispatchTxt,'xcorr2_nans_weighted_mex'));
verifyTrue(testCase,contains(dispatchTxt,'xcorr2_nans_weighted_fast'));
verifyTrue(testCase,contains(multiTxt,'xcorr2_nans_weighted_dispatch'));
end

function testCompilerGuardDoesNotMisclassifyMexBackendName(testCase)
% Explicitly regression-test the false positive that motivated this fix.
verifyFalse(testCase,containsCompilerInvocation( ...
    '[m,R,C] = xcorr2_nans_weighted_mex(frame,freshness,T,[0;0],5);'));
verifyTrue(testCase,containsCompilerInvocation( ...
    'mex(''-R2018a'',''xcorr2_nans_weighted_mex.cpp'');'));
verifyTrue(testCase,containsCompilerInvocation( ...
    sprintf('mex -R2018a xcorr2_nans_weighted_mex.cpp\n')));
verifyFalse(testCase,containsBuildHelperInvocation( ...
    'See buildWeightedXcorrMex separately before processing.'));
verifyTrue(testCase,containsBuildHelperInvocation( ...
    '[ok,report] = buildWeightedXcorrMex(''Strict'',true);'));
end

function testAdaptiveDefaultsRemainOff(testCase)
params = setParams('MultiRoiRegistration',struct());
verifyTrue(testCase,params.useFastWeightedXcorr);
verifyTrue(testCase,params.useMexWeightedXcorr);
verifyTrue(testCase,params.validateMexWeightedXcorr);
verifyFalse(testCase,params.useAdaptiveWeightedXcorr);
verifyEqual(testCase,params.adaptiveXcorrRadius,2);
verifyEqual(testCase,params.adaptiveXcorrAuditEvery,100);
end

function tf = containsCompilerInvocation(txt)
%CONTAINSCOMPILERINVOCATION Detect MATLAB's MEX compiler command as a token.
% Match either function syntax, e.g. mex(...), or command syntax when MEX is
% the first executable token on a line, e.g. "mex -R2018a file.cpp".
%
% Requiring a non-identifier boundary before mex prevents false positives for
% legitimate backend names such as xcorr2_nans_weighted_mex(...).
functionSyntax = '(?<![A-Za-z0-9_])mex\s*\(';
commandSyntax = '(?m)^\s*mex\s+';
tf = ~isempty(regexp(txt,functionSyntax,'once')) || ...
     ~isempty(regexp(txt,commandSyntax,'once'));
end

function tf = containsBuildHelperInvocation(txt)
%CONTAINSBUILDHELPERINVOCATION Detect an executable build-helper call.
functionSyntax = '(?<![A-Za-z0-9_])buildWeightedXcorrMex\s*\(';
commandSyntax = '(?m)^\s*buildWeightedXcorrMex\s+';
tf = ~isempty(regexp(txt,functionSyntax,'once')) || ...
     ~isempty(regexp(txt,commandSyntax,'once'));
end
