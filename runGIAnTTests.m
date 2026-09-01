function results = runGIAnTTests(giantRoot)
%RUNGIANTTESTS Run the GIAnT regression suite without manual suite concatenation.
%
%   results = runGIAnTTests()
%   results = runGIAnTTests(giantRoot)
%
% MATLAB R2024b can error when a matlab.unittest.TestSuite.empty object is
% manually horizontal-concatenated with objects returned by testsuite(file).
% Discover the folder as one suite instead.

if nargin < 1 || isempty(giantRoot)
    giantRoot = fileparts(mfilename('fullpath'));
end
giantRoot = char(giantRoot);
testDir = fullfile(giantRoot,'tests');

assert(isfolder(testDir),'GIAnT test directory not found: %s',testDir);

% Put this checkout first so tests do not silently exercise a stale copy.
addpath(giantRoot,'-begin');
addpath(genpath(fullfile(giantRoot,'dependencies')),'-begin');
addpath(fullfile(giantRoot,'motion_correction'),'-begin');
addpath(fullfile(giantRoot,'source_extraction'),'-begin');

suite = testsuite(testDir);
fprintf('Discovered %d GIAnT tests in %s\n',numel(suite),testDir);

results = run(suite);
disp(table(results));

if any([results.Failed])
    error('GIAnT:TestsFailed','%d GIAnT regression test(s) failed.',nnz([results.Failed]));
end
end
