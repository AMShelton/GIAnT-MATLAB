function tests = test_xcorr2_nans_weighted_fast
tests = functiontests(localfunctions);
end

function testMatchesReferenceAtZeroCenter(testCase)
rng(11);
frame = rand(41,53);
template = rand(41,53);
freshness = 0.5 + 3*rand(41,53);

frame(rand(size(frame))<0.12) = nan;
template(rand(size(template))<0.08) = nan;

[mRef,rRef] = xcorr2_nans_weighted(frame,freshness,template,[0;0],4);
[mFast,rFast] = xcorr2_nans_weighted_fast(frame,freshness,template,[0;0],4);

verifyEqual(testCase,mFast,mRef,'AbsTol',1e-12);
verifyEqual(testCase,rFast,rRef,'AbsTol',1e-12);
end

function testMatchesReferenceAtNonzeroCenter(testCase)
rng(12);
frame = rand(37,45);
template = rand(37,45);
freshness = 1 + rand(37,45);

frame(rand(size(frame))<0.1) = nan;
template(rand(size(template))<0.1) = nan;

center = [2;-1];
[mRef,rRef] = xcorr2_nans_weighted(frame,freshness,template,center,3);
[mFast,rFast] = xcorr2_nans_weighted_fast(frame,freshness,template,center,3);

verifyEqual(testCase,mFast,mRef,'AbsTol',1e-12);
verifyEqual(testCase,rFast,rRef,'AbsTol',1e-12);
end
