function [ok,report] = buildWeightedXcorrMex(varargin)
%BUILDWEIGHTEDXCORRMEX Build and validate the optional weighted-xcorr MEX.
%
%   [ok,report] = buildWeightedXcorrMex()
%
% This function is intentionally NEVER called by MultiRoiRegistration.
% Building is an explicit setup/maintenance action. If no supported C++
% compiler is configured, this function reports the condition and returns
% ok=false; production registration remains fully functional through
% xcorr2_nans_weighted_fast.m.
%
% Name-value options:
%   'Strict'       false : throw on build/validation failure instead of warn
%   'RunBenchmark' true  : benchmark MEX against MATLAB fast implementation
%
% The built binary is written next to this file, so it is found anywhere the
% GIAnT dependencies/alignment directory is on the MATLAB path.

p = inputParser;
p.addParameter('Strict',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('RunBenchmark',true,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
strict = p.Results.Strict;
runBenchmark = p.Results.RunBenchmark;

alignmentDir = fileparts(mfilename('fullpath'));
sourceFile = fullfile(alignmentDir,'xcorr2_nans_weighted_mex.cpp');
headerFile = fullfile(alignmentDir,'xcorr2_nans_weighted_core.hpp');
report = struct('compiler','','source',sourceFile,'output','', ...
    'built',false,'validated',false,'validation',struct(),'message','');
ok = false;

if ~isfile(sourceFile) || ~isfile(headerFile)
    report.message = 'MEX source/header files are missing.';
    finishFailure(report.message,strict);
    return
end

try
    cfg = mex.getCompilerConfigurations('C++','Selected');
catch ME
    report.message = sprintf('Could not query configured C++ compiler: %s',ME.message);
    finishFailure(report.message,strict);
    return
end

if isempty(cfg)
    report.message = ['No C++ MEX compiler is configured. Run "mex -setup C++" if MEX ' ...
        'acceleration is desired. GIAnT registration itself does not require a compiler.'];
    finishFailure(report.message,strict);
    return
end

report.compiler = cfg.Name;
fprintf('Building weighted-xcorr MEX with: %s\n',cfg.Name);

try
    mex('-R2018a','-O',sourceFile,'-outdir',alignmentDir, ...
        '-output','xcorr2_nans_weighted_mex');
    clear xcorr2_nans_weighted_mex xcorr2_nans_weighted_dispatch
    rehash
catch ME
    report.message = sprintf('MEX compilation failed: %s: %s',ME.identifier,ME.message);
    finishFailure(report.message,strict);
    return
end

report.output = which('xcorr2_nans_weighted_mex');
report.built = exist('xcorr2_nans_weighted_mex','file') == 3;
if ~report.built
    report.message = 'Compilation returned without error, but the MEX binary is not loadable.';
    finishFailure(report.message,strict);
    return
end

try
    validation = validateWeightedXcorrMex('RunBenchmark',runBenchmark,'Strict',true);
    report.validation = validation;
    report.validated = validation.passed;
    ok = validation.passed;
catch ME
    report.message = sprintf('Compiled MEX failed validation: %s: %s',ME.identifier,ME.message);
    % Leave the binary for inspection but dispatch will reject it on first-use
    % validation and fall back safely in production.
    finishFailure(report.message,strict);
    return
end

if ok
    fprintf('Weighted-xcorr MEX build and validation PASSED.\n');
    fprintf('Binary: %s\n',report.output);
    % Process workers can retain a previously-loaded/fallback persistent
    % backend state. Restart an existing pool after a successful rebuild so
    % the next MultiRoiRegistration run starts workers against this binary.
    pool = gcp('nocreate');
    if ~isempty(pool)
        fprintf('Closing existing parallel pool so workers reload the validated MEX on next use.\n');
        delete(pool);
    end
end
end


function finishFailure(message,strict)
if strict
    error('buildWeightedXcorrMex:Failed','%s',message);
else
    warning('buildWeightedXcorrMex:Failed', ...
        '%s Registration will continue to use the MATLAB fast fallback.',message);
end
end
