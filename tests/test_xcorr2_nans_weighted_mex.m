function tests = test_xcorr2_nans_weighted_mex
tests = functiontests(localfunctions);
end

function testRandomizedMexMatchesFast(testCase)
assumeTrue(testCase,exist('xcorr2_nans_weighted_mex','file') == 3, ...
    'Optional MEX binary is not built on this machine.');
rng(23);
for iteration = 1:10
    sz = [35+randi(20), 41+randi(20)];
    frame = randn(sz);
    template = randn(sz);
    freshness = 0.1 + 4*rand(sz);
    frame(rand(sz)<0.16) = nan;
    template(rand(sz)<0.12) = nan;
    center = [randi(5)-3; randi(5)-3];
    radius = randi([1 5]);

    [mRef,rRef,cRef] = xcorr2_nans_weighted_fast( ...
        frame,freshness,template,center,radius);
    [mMex,rMex,cMex] = xcorr2_nans_weighted_mex( ...
        frame,freshness,template,center,double(radius));

    verifyEqual(testCase,isnan(cMex),isnan(cRef));
    verifyEqual(testCase,cMex,cRef,'AbsTol',5e-10);
    verifyEqual(testCase,rMex,rRef,'AbsTol',5e-10);
    verifyEqual(testCase,mMex,mRef,'AbsTol',5e-9);
end
end
