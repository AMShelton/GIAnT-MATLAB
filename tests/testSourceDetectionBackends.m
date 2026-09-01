function tests = testSourceDetectionBackends
%TESTSOURCEDETECTIONBACKENDS Basic regression/smoke tests for detector dispatch.
tests = functiontests(localfunctions);
end

function testSummarizeLoCoSelectsDominantSeparatedPeak(testCase)
raw = zeros(64,64);
raw(20,20) = 10;
raw(45,45) = 2;
nanFrac = zeros(size(raw));
somaMask = false(size(raw));

p = struct();
p.sourceDetectionMethod = 'summarize_loco';
p.maxSynapseDensity = 1e-3;
p.dXY = 1;
p.nanThresh = 0.5;

[s, im, info] = detectSourcesFromActivityImage(raw, nanFrac, somaMask, p);

verifyEqual(testCase, info.method, 'summarize_loco');
verifySize(testCase, im, size(raw));
verifyEqual(testCase, numel(s.R), 1);
verifyEqual(testCase, [s.R(1) s.C(1)], [20 20]);
end

function testAliasesNormalize(testCase)
raw = zeros(32,32);
raw(10,10) = 10;
raw(25,25) = 2;
nanFrac = zeros(size(raw));
somaMask = false(size(raw));

p = struct('sourceDetectionMethod','loco', ...
    'maxSynapseDensity',1e-3,'dXY',1,'nanThresh',0.5);
[~,~,info] = detectSourcesFromActivityImage(raw,nanFrac,somaMask,p);
verifyEqual(testCase, info.method, 'summarize_loco');
end

function testUnknownBackendErrors(testCase)
raw = zeros(8,8);
p = struct('sourceDetectionMethod','not_a_backend', ...
    'nanThresh',0.5,'dXY',1);
verifyError(testCase, ...
    @() detectSourcesFromActivityImage(raw,zeros(8),false(8),p), ...
    'SILo:UnknownSourceDetectionMethod');
end
