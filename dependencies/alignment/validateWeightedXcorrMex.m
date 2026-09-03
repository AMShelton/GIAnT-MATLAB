function report = validateWeightedXcorrMex(varargin)
%VALIDATEWEIGHTEDXCORRMEX Numerical regression tests and benchmark for MEX.
%
% report = validateWeightedXcorrMex()
%
% This validates the optional MEX backend against the current exact MATLAB
% fast implementation over randomized NaN/freshness/search-center cases.
% It does not modify GIAnT parameters or compile anything.
%
% Name-value options:
%   'Strict'       false
%   'RunBenchmark' true
%   'Iterations'   24
%   'BenchmarkSize' [256 384]

p = inputParser;
p.addParameter('Strict',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('RunBenchmark',true,@(x)islogical(x)&&isscalar(x));
p.addParameter('Iterations',24,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
p.addParameter('BenchmarkSize',[256 384],@(x)isnumeric(x)&&numel(x)==2&&all(x>8));
p.parse(varargin{:});
opts = p.Results;

report = struct('available',false,'passed',false,'iterations',0, ...
    'maxMotionError',NaN,'maxRError',NaN,'maxSurfaceError',NaN, ...
    'matlabFastSeconds',NaN,'mexSeconds',NaN,'speedup',NaN,'message','');

if exist('xcorr2_nans_weighted_mex','file') ~= 3
    report.message = 'xcorr2_nans_weighted_mex is not available.';
    if opts.Strict
        error('validateWeightedXcorrMex:Unavailable','%s',report.message);
    else
        fprintf('Weighted-xcorr MEX unavailable; MATLAB fallback remains active.\n');
        return
    end
end
report.available = true;

rng(20260903,'twister');
maxME = 0;
maxRE = 0;
maxCE = 0;

for iteration = 1:round(opts.Iterations)
    sz = [31+randi(39), 37+randi(45)];
    frame = randn(sz);
    template = randn(sz);
    freshness = 0.1 + 4*rand(sz);
    frame(rand(sz)<0.15) = nan;
    template(rand(sz)<0.12) = nan;
    center = [randi(7)-4; randi(7)-4];
    radius = randi([1 5]);

    [mRef,rRef,cRef] = xcorr2_nans_weighted_fast( ...
        frame,freshness,template,center,radius);
    [mMex,rMex,cMex] = xcorr2_nans_weighted_mex( ...
        frame,freshness,template,center,double(radius));

    verifySameNaNPattern(cRef,cMex,iteration);
    finite = isfinite(cRef) & isfinite(cMex);
    if any(finite,'all')
        maxCE = max(maxCE,max(abs(cRef(finite)-cMex(finite)),[],'all'));
    end
    maxME = max(maxME,max(abs(mRef(:)-mMex(:)),[],'all'));
    if isfinite(rRef) && isfinite(rMex)
        maxRE = max(maxRE,abs(rRef-rMex));
    elseif ~(isnan(rRef) && isnan(rMex))
        error('validateWeightedXcorrMex:RNaNMismatch', ...
            'R finite/NaN mismatch on randomized iteration %d.',iteration);
    end
end

report.iterations = round(opts.Iterations);
report.maxMotionError = maxME;
report.maxRError = maxRE;
report.maxSurfaceError = maxCE;

% MEX reduction order can differ slightly from MATLAB's internal reduction,
% so validate to tight floating-point tolerances rather than byte identity.
report.passed = maxME <= 5e-9 && maxRE <= 5e-10 && maxCE <= 5e-10;
if ~report.passed
    report.message = sprintf( ...
        'Numerical tolerance failure: motion=%g, R=%g, C=%g.',maxME,maxRE,maxCE);
    if opts.Strict
        error('validateWeightedXcorrMex:NumericalMismatch','%s',report.message);
    end
end

if opts.RunBenchmark && report.passed
    sz = round(opts.BenchmarkSize(:)');
    frame = rand(sz);
    template = rand(sz);
    freshness = 0.25 + 2*rand(sz);
    frame(rand(sz)<0.12) = nan;
    template(rand(sz)<0.08) = nan;

    fastFcn = @() xcorr2_nans_weighted_fast(frame,freshness,template,[0;0],5);
    mexFcn = @() xcorr2_nans_weighted_mex(frame,freshness,template,[0;0],5);
    report.matlabFastSeconds = timeit(fastFcn);
    report.mexSeconds = timeit(mexFcn);
    report.speedup = report.matlabFastSeconds/report.mexSeconds;
end

fprintf(['Weighted-xcorr MEX validation: %d randomized cases; max |dmotion| %.3g, ' ...
    'max |dR| %.3g, max |dC| %.3g.\n'], ...
    report.iterations,report.maxMotionError,report.maxRError,report.maxSurfaceError);
if opts.RunBenchmark && report.passed
    fprintf('MEX benchmark: MATLAB-fast %.4f s; MEX %.4f s; speedup %.2fx\n', ...
        report.matlabFastSeconds,report.mexSeconds,report.speedup);
end
end


function verifySameNaNPattern(a,b,iteration)
if ~isequal(isnan(a),isnan(b))
    error('validateWeightedXcorrMex:NaNPatternMismatch', ...
        'Correlation-surface NaN pattern differs on randomized iteration %d.',iteration);
end
end
