function results = verifyMultiRoiUpgrade
%VERIFYMULTIROIUPGRADE Run focused regression tests for the registration patch.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));

testFiles = { ...
    fullfile(root,'tests','test_xcorr2_nans_weighted_fast.m'), ...
    fullfile(root,'tests','test_getOnlineMotion.m'), ...
    fullfile(root,'tests','test_MultiRoiRegistration_streaming_source.m')};
results = runtests(testFiles);
disp(results);
if any([results.Failed])
    error('verifyMultiRoiUpgrade:TestsFailed', ...
        '%d focused MultiROI regression test(s) failed.',nnz([results.Failed]));
end

% Synthetic hot-path benchmark. This does not replace testing on real SLAP2
% frames; it makes a local performance regression immediately visible.
rng(20260902);
frame = rand(256,384);
template = rand(256,384);
freshness = 0.25 + 2*rand(256,384);
frame(rand(size(frame))<0.12) = nan;
template(rand(size(template))<0.08) = nan;

legacyFcn = @() xcorr2_nans_weighted(frame,freshness,template,[0;0],5);
fastFcn = @() xcorr2_nans_weighted_fast(frame,freshness,template,[0;0],5);
legacySeconds = timeit(legacyFcn);
fastSeconds = timeit(fastFcn);
fprintf('xcorr synthetic benchmark: legacy %.3f s; fast %.3f s; speedup %.2fx\n', ...
    legacySeconds,fastSeconds,legacySeconds/fastSeconds);
end
