function results = verifyMultiRoiUpgrade(h5TestDir)
%VERIFYMULTIROIUPGRADE Run focused registration/HDF5 regression tests.
%   verifyMultiRoiUpgrade() runs unit tests plus an HDF5 round-trip stress
%   test in TEMPDIR.
%
%   verifyMultiRoiUpgrade(h5TestDir) runs the same HDF5 stress test in the
%   supplied directory. Passing the actual network-backed dynamic_data or
%   motion_correction directory is recommended before a long processing run,
%   because it exercises the filesystem that previously produced transient
%   H5CREATE -> H5WRITE visibility failures.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
if nargin < 1 || isempty(h5TestDir)
    h5TestDir = tempdir;
end
if ~isfolder(h5TestDir)
    error('verifyMultiRoiUpgrade:MissingTestDirectory', ...
        'HDF5 test directory does not exist: %s',h5TestDir);
end

testFiles = { ...
    fullfile(root,'tests','test_xcorr2_nans_weighted_fast.m'), ...
    fullfile(root,'tests','test_xcorr2_nans_weighted_dispatch.m'), ...
    fullfile(root,'tests','test_getOnlineMotion.m'), ...
    fullfile(root,'tests','test_MultiRoiRegistration_streaming_source.m'), ...
    fullfile(root,'tests','test_saveStructToH5_robust.m')};
if exist('xcorr2_nans_weighted_mex','file') == 3
    testFiles{end+1} = fullfile(root,'tests','test_xcorr2_nans_weighted_mex.m');
end
results = runtests(testFiles);
disp(results);
if any([results.Failed])
    error('verifyMultiRoiUpgrade:TestsFailed', ...
        '%d focused MultiROI regression test(s) failed.',nnz([results.Failed]));
end

runH5FilesystemStressTest(h5TestDir);

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

if exist('xcorr2_nans_weighted_mex','file') == 3
    mexReport = validateWeightedXcorrMex('Strict',true,'RunBenchmark',true);
    fprintf('xcorr MEX status: validated; speedup vs MATLAB-fast %.2fx\n',mexReport.speedup);
else
    fprintf(['xcorr MEX status: optional binary not present. This is NOT a test failure; ' ...
        'MultiRoiRegistration will use the MATLAB-fast fallback.\n']);
end
end


function runH5FilesystemStressTest(testDir)
% Repeatedly exercise the exact saveStructToH5 pattern that failed on VAST.
fprintf('HDF5 filesystem stress test: %s\n',testDir);
for ix = 1:8
    fn = [tempname(testDir) '.h5'];
    cleanup = onCleanup(@() deleteIfPresent(fn));
    s = struct();
    s.numChannels = 2;
    s.frametime = 1/80;
    s.alignHz = 80;
    s.DSframes = 1:1497;
    s.slap2 = struct();
    s.slap2.Z_depths = -42.5;
    s.slap2.cropRow = 3;
    s.slap2.cropCol = 4;
    s.slap2.viewC = reshape(1:120,10,12);
    s.slap2.viewR = reshape(121:240,10,12);
    s.slap2.trimRows = 5:25;
    s.slap2.trimCols = 7:30;

    saveStructToH5(s,fn);
    assert(isequal(h5read(fn,'/DSframes'),s.DSframes), ...
        'verifyMultiRoiUpgrade:H5RoundTrip','DSframes round-trip failed.');
    assert(isequal(h5read(fn,'/slap2/viewC'),s.slap2.viewC), ...
        'verifyMultiRoiUpgrade:H5RoundTrip','viewC round-trip failed.');
    clear cleanup
    deleteIfPresent(fn);
end
fprintf('HDF5 filesystem stress test passed (8/8 files).\n');
end


function deleteIfPresent(fn)
if exist(fn,'file')
    delete(fn);
end
end
