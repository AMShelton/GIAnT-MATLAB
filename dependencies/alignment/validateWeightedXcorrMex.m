function report = validateWeightedXcorrMex(varargin)
%VALIDATEWEIGHTEDXCORRMEX Numerical regression tests and representative benchmark.
%
% Validates the optional MEX backend against xcorr2_nans_weighted_fast for
% the precision combinations used by real SLAP2 MultiRoiRegistration:
%   double / double / double   (generic regression reference)
%   single / single / single   (initial-template correlations)
%   single / single / double   (main registration correlations)
%
% No compilation or GIAnT parameter changes occur here.

p = inputParser;
p.addParameter('Strict',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('RunBenchmark',true,@(x)islogical(x)&&isscalar(x));
p.addParameter('Iterations',24,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
p.addParameter('BenchmarkSize',[256 384],@(x)isnumeric(x)&&numel(x)==2&&all(x>8));
p.parse(varargin{:});
opts = p.Results;

report = struct('available',false,'passed',false,'iterations',0, ...
    'maxMotionError',NaN,'maxRError',NaN,'maxSurfaceError',NaN, ...
    'samePeak',true,'classCases',struct([]), ...
    'matlabFastSeconds',NaN,'mexSeconds',NaN,'speedup',NaN, ...
    'initialTemplateSpeedup',NaN,'benchmark',struct(),'message','');

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

classDefs = { ...
    'double/double/double', 'double','double','double'; ...
    'single/single/single', 'single','single','single'; ...
    'single/single/double', 'single','single','double'};

rng(20260903,'twister');
maxME = 0; maxRE = 0; maxCE = 0; allSamePeak = true;
caseReports = repmat(struct('signature','','iterations',0,'maxMotionError',0, ...
    'maxRError',0,'maxSurfaceError',0,'samePeak',true,'passed',false), ...
    size(classDefs,1),1);

for caseIx = 1:size(classDefs,1)
    signature = classDefs{caseIx,1};
    frameClass = classDefs{caseIx,2};
    freshnessClass = classDefs{caseIx,3};
    templateClass = classDefs{caseIx,4};
    cMax = 0; mMax = 0; rMax = 0; samePeakCase = true;

    for iteration = 1:round(opts.Iterations)
        sz = [31+randi(39), 37+randi(45)];
        frame0 = randn(sz);
        template0 = randn(sz);
        freshness0 = 0.1 + 4*rand(sz);
        frame0(rand(sz)<0.15) = nan;
        template0(rand(sz)<0.12) = nan;

        frame = cast(frame0,frameClass);
        freshness = cast(freshness0,freshnessClass);
        template = cast(template0,templateClass);
        center = [randi(7)-4; randi(7)-4];
        radius = randi([1 5]);

        [mRef,rRef,cRef] = xcorr2_nans_weighted_fast( ...
            frame,freshness,template,center,radius);
        [mMex,rMex,cMex] = xcorr2_nans_weighted_mex( ...
            frame,freshness,template,center,double(radius));

        verifySameNaNPattern(cRef,cMex,signature,iteration);
        samePeak = sameCorrelationPeak(cRef,cMex);
        samePeakCase = samePeakCase && samePeak;

        finite = isfinite(cRef) & isfinite(cMex);
        if any(finite,'all')
            cMax = max(cMax,max(abs(cRef(finite)-cMex(finite)),[],'all'));
        end
        mMax = max(mMax,max(abs(mRef(:)-mMex(:)),[],'all'));
        if isfinite(rRef) && isfinite(rMex)
            rMax = max(rMax,abs(rRef-rMex));
        elseif ~(isnan(rRef) && isnan(rMex))
            error('validateWeightedXcorrMex:RNaNMismatch', ...
                'R finite/NaN mismatch for %s on randomized iteration %d.', ...
                signature,iteration);
        end
    end

    [cTol,mTol,rTol] = tolerancesForSignature(signature);
    passedCase = samePeakCase && cMax <= cTol && mMax <= mTol && rMax <= rTol;
    caseReports(caseIx) = struct('signature',signature, ...
        'iterations',round(opts.Iterations),'maxMotionError',mMax, ...
        'maxRError',rMax,'maxSurfaceError',cMax, ...
        'samePeak',samePeakCase,'passed',passedCase);

    maxME = max(maxME,mMax); maxRE = max(maxRE,rMax); maxCE = max(maxCE,cMax);
    allSamePeak = allSamePeak && samePeakCase;

    fprintf(['Weighted-xcorr MEX validation %s: %d cases; same peak %d; ' ...
        'max |dmotion| %.3g, max |dR| %.3g, max |dC| %.3g.\n'], ...
        signature,round(opts.Iterations),samePeakCase,mMax,rMax,cMax);
end

report.iterations = round(opts.Iterations);
report.maxMotionError = maxME;
report.maxRError = maxRE;
report.maxSurfaceError = maxCE;
report.samePeak = allSamePeak;
report.classCases = caseReports;
report.passed = all([caseReports.passed]);

if ~report.passed
    failed = caseReports(~[caseReports.passed]);
    report.message = sprintf('Numerical validation failed for: %s.', ...
        strjoin({failed.signature},', '));
    if opts.Strict
        error('validateWeightedXcorrMex:NumericalMismatch','%s',report.message);
    end
end

if opts.RunBenchmark && report.passed
    sz = round(opts.BenchmarkSize(:)');
    frame0 = rand(sz);
    template0 = rand(sz);
    freshness0 = 0.25 + 2*rand(sz);
    frame0(rand(sz)<0.12) = nan;
    template0(rand(sz)<0.08) = nan;

    frameS = single(frame0);
    freshS = single(freshness0);
    templS = single(template0);
    templD = double(template0);

    bInit = benchmarkCase(frameS,freshS,templS);
    bMain = benchmarkCase(frameS,freshS,templD);
    report.benchmark = struct('singleSingleSingle',bInit, ...
        'singleSingleDouble',bMain);

    % Preserve legacy top-level fields as the main-registration benchmark.
    report.matlabFastSeconds = bMain.matlabFastSeconds;
    report.mexSeconds = bMain.mexSeconds;
    report.speedup = bMain.speedup;
    report.initialTemplateSpeedup = bInit.speedup;

    fprintf(['MEX benchmark template single/single/single: MATLAB-fast %.4f s; ' ...
        'MEX %.4f s; speedup %.2fx\n'], ...
        bInit.matlabFastSeconds,bInit.mexSeconds,bInit.speedup);
    fprintf(['MEX benchmark main single/single/double: MATLAB-fast %.4f s; ' ...
        'MEX %.4f s; speedup %.2fx\n'], ...
        bMain.matlabFastSeconds,bMain.mexSeconds,bMain.speedup);
end
end


function b = benchmarkCase(frame,freshness,template)
fastFcn = @() xcorr2_nans_weighted_fast(frame,freshness,template,[0;0],5);
mexFcn = @() xcorr2_nans_weighted_mex(frame,freshness,template,[0;0],5);
b = struct();
b.matlabFastSeconds = timeit(fastFcn);
b.mexSeconds = timeit(mexFcn);
b.speedup = b.matlabFastSeconds/b.mexSeconds;
end


function [cTol,mTol,rTol] = tolerancesForSignature(signature)
if contains(signature,'single')
    % Real SLAP2 single-precision frames can differ at O(1e-5) between
    % MATLAB and MEX purely because the reduction order differs. Keep the
    % integer-peak requirement exact and subpixel-motion tolerance at 5e-4.
    cTol = 5e-5;
    rTol = 5e-5;
    mTol = 5e-4;
else
    cTol = 5e-10;
    rTol = 5e-10;
    mTol = 5e-9;
end
end


function tf = sameCorrelationPeak(a,b)
[~,ia] = max(a(:));
[~,ib] = max(b(:));
tf = isequal(ia,ib);
end


function verifySameNaNPattern(a,b,signature,iteration)
if ~isequal(isnan(a),isnan(b))
    error('validateWeightedXcorrMex:NaNPatternMismatch', ...
        'Correlation-surface NaN pattern differs for %s on iteration %d.', ...
        signature,iteration);
end
end
