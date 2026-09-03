function [motion,R,C,info] = xcorr2_nans_weighted_dispatch(frame,freshness,template,shiftsCenter,dShift,opts)
%XCORR2_NANS_WEIGHTED_DISPATCH Safe accelerated weighted local correlation.
%
% Production safety contract:
%   1) this function NEVER compiles a MEX binary;
%   2) if the optional MEX is absent, incompatible, fails validation, or
%      throws at runtime, the current xcorr2_nans_weighted_fast MATLAB path
%      is used immediately instead;
%   3) MEX failure is sticky for the lifetime of this MATLAB process/worker,
%      preventing repeated failures inside a long registration run;
%   4) optional adaptive search is OFF by default and is independent of MEX.
%
% opts fields (all optional):
%   useMex                 default true
%   validateMexOnFirstUse  default true
%   useAdaptive            default false
%   adaptiveRadius         default 2
%   adaptiveAuditEvery     default 100
%   adaptiveMinCorrelation default -1
%
% INFO reports the backend/search actually used.

if nargin < 6 || isempty(opts)
    opts = struct();
end
opts = normalizeOptions(opts,dShift);

persistent mexState mexFailureMessage mexWarningIssued ...
    adaptiveCounter adaptiveDisabled adaptiveWarningIssued
% mexState: 0 unknown/not yet probed, 1 validated usable, -1 disabled.
if isempty(mexState), mexState = 0; end
if isempty(mexFailureMessage), mexFailureMessage = ''; end
if isempty(mexWarningIssued), mexWarningIssued = false; end
if isempty(adaptiveCounter), adaptiveCounter = 0; end
if isempty(adaptiveDisabled), adaptiveDisabled = false; end
if isempty(adaptiveWarningIssued), adaptiveWarningIssued = false; end

info = struct('backend','','requestedRadius',double(dShift), ...
    'usedRadius',double(dShift),'expandedToFull',false, ...
    'adaptiveAudit',false,'adaptiveDisabled',adaptiveDisabled, ...
    'mexFailureMessage',mexFailureMessage);

% Probe only when MEX use was requested and the actual inputs are supported.
% Unsupported input classes simply use MATLAB-fast without poisoning MEX for
% a later compatible call.
mexInputCompatible = compatibleMexInputs(frame,freshness,template);
if opts.useMex && mexInputCompatible && mexState == 0
    [usable,msg] = probeMexBackend(opts.validateMexOnFirstUse, ...
        frame,freshness,template,shiftsCenter,dShift);
    if usable
        mexState = 1;
        mexFailureMessage = '';
    else
        mexState = -1;
        mexFailureMessage = msg;
        if ~mexWarningIssued
            if exist('xcorr2_nans_weighted_mex','file') == 3
                warning('xcorr2_nans_weighted_dispatch:MexValidationFailed', ...
                    ['Weighted-xcorr MEX backend is unusable (%s). Falling back to ' ...
                     'xcorr2_nans_weighted_fast for this MATLAB process/worker.'],msg);
            else
                warning('xcorr2_nans_weighted_dispatch:MexUnavailable', ...
                    ['Weighted-xcorr MEX backend is not available. Falling back to the ' ...
                     'current xcorr2_nans_weighted_fast implementation. Registration ' ...
                     'will continue normally. Run buildWeightedXcorrMex separately ' ...
                     'if MEX acceleration is desired.']);
            end
            mexWarningIssued = true;
        end
    end
end

useMexNow = opts.useMex && mexInputCompatible && mexState == 1;

% Adaptive search is deliberately a caller-controlled optional layer. The
% exact full-radius path is the production default.
useAdaptiveNow = opts.useAdaptive && ~adaptiveDisabled && dShift > opts.adaptiveRadius;
if useAdaptiveNow
    adaptiveCounter = adaptiveCounter + 1;
    auditNow = opts.adaptiveAuditEvery > 0 && ...
        mod(adaptiveCounter,opts.adaptiveAuditEvery) == 0;

    [motionSmall,rSmall,cSmall,backendSmall,mexFailed,mexMsg] = callBackend( ...
        frame,freshness,template,shiftsCenter,opts.adaptiveRadius,useMexNow);
    if mexFailed
        [mexState,mexFailureMessage,mexWarningIssued] = disableMexAfterRuntimeFailure( ...
            mexMsg,mexWarningIssued);
        useMexNow = false;
    end

    expand = auditNow || ~isfinite(rSmall) || rSmall < opts.adaptiveMinCorrelation || ...
        peakTouchesBoundary(cSmall);

    if ~expand
        motion = motionSmall;
        R = rSmall;
        C = cSmall;
        info.backend = backendSmall;
        info.usedRadius = opts.adaptiveRadius;
        info.adaptiveDisabled = adaptiveDisabled;
        info.mexFailureMessage = mexFailureMessage;
        return
    end

    [motionFull,rFull,cFull,backendFull,mexFailed,mexMsg] = callBackend( ...
        frame,freshness,template,shiftsCenter,dShift,useMexNow);
    if mexFailed
        [mexState,mexFailureMessage,mexWarningIssued] = disableMexAfterRuntimeFailure( ...
            mexMsg,mexWarningIssued);
    end

    if auditNow && ~sameMotionPeak(motionSmall,rSmall,motionFull,rFull)
        adaptiveDisabled = true;
        if ~adaptiveWarningIssued
            warning('xcorr2_nans_weighted_dispatch:AdaptiveDisabled', ...
                ['Adaptive weighted xcorr disagreed with a periodic full-search audit. ' ...
                 'Adaptive mode is disabled for this MATLAB process/worker; full-radius ' ...
                 'correlation will be used for subsequent frames.']);
            adaptiveWarningIssued = true;
        end
    end

    % Audit/boundary/low-R frames always use the scientifically conservative
    % full search result.
    motion = motionFull;
    R = rFull;
    C = cFull;
    info.backend = backendFull;
    info.usedRadius = double(dShift);
    info.expandedToFull = true;
    info.adaptiveAudit = auditNow;
    info.adaptiveDisabled = adaptiveDisabled;
    info.mexFailureMessage = mexFailureMessage;
    return
end

[motion,R,C,backend,mexFailed,mexMsg] = callBackend( ...
    frame,freshness,template,shiftsCenter,dShift,useMexNow);
if mexFailed
    [mexState,mexFailureMessage,mexWarningIssued] = disableMexAfterRuntimeFailure( ...
        mexMsg,mexWarningIssued);
end
info.backend = backend;
info.adaptiveDisabled = adaptiveDisabled;
info.mexFailureMessage = mexFailureMessage;
end


function [motion,R,C,backend,mexFailed,mexMessage] = callBackend(frame,freshness,template,shiftsCenter,dShift,useMexNow)
mexFailed = false;
mexMessage = '';
if useMexNow
    try
        [motion,R,C] = xcorr2_nans_weighted_mex( ...
            frame,freshness,template,shiftsCenter,double(dShift));
        backend = 'mex';
        return
    catch ME
        mexFailed = true;
        mexMessage = sprintf('%s: %s',ME.identifier,ME.message);
        % Current call is recomputed with the existing MATLAB fast path.
        [motion,R,C] = xcorr2_nans_weighted_fast( ...
            frame,freshness,template,shiftsCenter,dShift);
        backend = 'matlab-fast-after-mex-failure';
        return
    end
end

[motion,R,C] = xcorr2_nans_weighted_fast( ...
    frame,freshness,template,shiftsCenter,dShift);
backend = 'matlab-fast';
end


function [state,msg,warned] = disableMexAfterRuntimeFailure(msg,warned)
state = -1;
if ~warned
    warning('xcorr2_nans_weighted_dispatch:MexRuntimeFallback', ...
        ['Weighted-xcorr MEX failed at runtime (%s). The current frame was ' ...
         'recomputed with xcorr2_nans_weighted_fast, and MEX has been disabled ' ...
         'for this MATLAB process/worker. Registration will continue.'],msg);
    warned = true;
end
end


function tf = compatibleMexInputs(frame,freshness,template)
tf = isa(frame,'double') && isa(freshness,'double') && isa(template,'double') && ...
    isreal(frame) && isreal(freshness) && isreal(template) && ...
    ~issparse(frame) && ~issparse(freshness) && ~issparse(template) && ...
    ismatrix(frame) && ismatrix(freshness) && ismatrix(template);
end


function [usable,msg] = probeMexBackend(validateNumerics,frame,freshness,template,shiftsCenter,dShift)
usable = false;
msg = '';
if exist('xcorr2_nans_weighted_mex','file') ~= 3
    msg = 'MEX binary not found or not loadable on this MATLAB installation';
    return
end
if ~validateNumerics
    usable = true;
    return
end

try
    % Strong guardrail: validate on the FIRST ACTUAL GIAnT correlation input
    % seen by each MATLAB process/parallel worker. This checks the real image
    % dimensions, NaN layout, freshness weights, search center, and radius.
    % It costs one extra MATLAB-fast + MEX evaluation per worker, which is
    % negligible compared with a full pseudo-trial.
    [mRef,rRef,cRef] = xcorr2_nans_weighted_fast( ...
        frame,freshness,template,shiftsCenter,dShift);
    [mMex,rMex,cMex] = xcorr2_nans_weighted_mex( ...
        frame,freshness,template,shiftsCenter,double(dShift));

    sameNaNs = isequal(isnan(cRef),isnan(cMex));
    finite = isfinite(cRef) & isfinite(cMex);
    if any(finite,'all')
        cErr = max(abs(cRef(finite)-cMex(finite)),[],'all');
    else
        cErr = 0;
    end
    mErr = max(abs(mRef(:)-mMex(:)),[],'all');
    if isfinite(rRef) && isfinite(rMex)
        rErr = abs(rRef-rMex);
    else
        rErr = double(~(isnan(rRef) && isnan(rMex)));
    end

    usable = sameNaNs && cErr <= 5e-10 && mErr <= 5e-9 && rErr <= 5e-10;
    if ~usable
        msg = sprintf('real-input numerical mismatch: max |dC|=%g, |dmotion|=%g, |dR|=%g', ...
            cErr,mErr,rErr);
    end
catch ME
    msg = sprintf('%s: %s',ME.identifier,ME.message);
end
end

function tf = peakTouchesBoundary(C)
if isempty(C) || all(isnan(C),'all')
    tf = true;
    return
end
[~,I] = max(C(:));
[rr,cc] = ind2sub(size(C),I);
tf = rr == 1 || rr == size(C,1) || cc == 1 || cc == size(C,2);
end


function tf = sameMotionPeak(mSmall,rSmall,mFull,rFull)
tf = all(isfinite(mSmall)) && all(isfinite(mFull)) && ...
    max(abs(mSmall(:)-mFull(:))) <= 1e-6;
if isfinite(rSmall) && isfinite(rFull)
    tf = tf && abs(rSmall-rFull) <= 1e-8;
else
    tf = false;
end
end


function opts = normalizeOptions(opts,dShift)
defaults = struct( ...
    'useMex',true, ...
    'validateMexOnFirstUse',true, ...
    'useAdaptive',false, ...
    'adaptiveRadius',2, ...
    'adaptiveAuditEvery',100, ...
    'adaptiveMinCorrelation',-1);
fields = fieldnames(defaults);
for k = 1:numel(fields)
    f = fields{k};
    if ~isfield(opts,f) || isempty(opts.(f))
        opts.(f) = defaults.(f);
    end
end

opts.useMex = logicalScalarLocal(opts.useMex,'useMex');
opts.validateMexOnFirstUse = logicalScalarLocal(opts.validateMexOnFirstUse,'validateMexOnFirstUse');
opts.useAdaptive = logicalScalarLocal(opts.useAdaptive,'useAdaptive');
validateattributes(opts.adaptiveRadius,{'numeric'},{'scalar','real','finite','nonnegative'}, ...
    mfilename,'adaptiveRadius');
opts.adaptiveRadius = min(round(double(opts.adaptiveRadius)),round(double(dShift)));
validateattributes(opts.adaptiveAuditEvery,{'numeric'},{'scalar','real','finite','nonnegative'}, ...
    mfilename,'adaptiveAuditEvery');
opts.adaptiveAuditEvery = round(double(opts.adaptiveAuditEvery));
validateattributes(opts.adaptiveMinCorrelation,{'numeric'}, ...
    {'scalar','real','finite','>=',-1,'<=',1},mfilename,'adaptiveMinCorrelation');
end


function tf = logicalScalarLocal(value,name)
if islogical(value) && isscalar(value)
    tf = value;
elseif isnumeric(value) && isscalar(value) && isfinite(value) && (value==0 || value==1)
    tf = logical(value);
else
    error('xcorr2_nans_weighted_dispatch:InvalidOption', ...
        '%s must be a logical scalar or numeric 0/1.',name);
end
end
