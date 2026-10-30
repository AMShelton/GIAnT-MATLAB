function [cTol,mTol,rTol,detail] = weightedXcorrMexTolerances(frame,freshness,template,cRef)
%WEIGHTEDXCORRMEXTOLERANCES Acceptance tolerances for MEX-vs-MATLAB weighted xcorr.
%   [cTol,mTol,rTol,detail] = weightedXcorrMexTolerances(frame,freshness,template,cRef)
%
%   Shared by xcorr2_nans_weighted_dispatch (first-use validation on real
%   frames) and validateWeightedXcorrMex (randomized regression tool) so both
%   apply the same acceptance rule.
%
%   Why the tolerances look the way they do
%   ---------------------------------------
%   The MEX reproduces the MATLAB arithmetic class-for-class but accumulates
%   sequentially, while MATLAB's sum/mean use pairwise (vectorised) reduction.
%   For SINGLE inputs over ~1e6-pixel SLAP2 frames the two orders legitimately
%   differ by O(1e-5 .. 1e-4) in the correlation surface C. Neither result is
%   "more correct"; both are single-precision approximations of the same
%   statistic. A fixed 5e-5 surface tolerance therefore sat exactly on the
%   noise floor and made first-use validation a coin flip per worker (in a
%   real run 5 of 8 workers fell back to the 3x slower MATLAB path with
%   |dC| = 4.9e-5 .. 5.06e-5).
%
%   The subpixel motion is computed from C by a 3-point ratio formula, so its
%   sensitivity to surface noise is ~1/curvature of the peak. A flat peak
%   (low-SNR frame) turns a 5e-5 surface difference into ~1e-3 px of motion
%   difference even though both implementations agree to within noise. The
%   motion tolerance is therefore DERIVED from the surface tolerance and the
%   measured peak curvature of the reference surface, with a floor that is far
%   below any scientifically meaningful displacement (1e-2 px = 2.5 nm at the
%   250 nm SLAP2 pixel) and a cap so that a gross bug is still caught.
%
%   DOUBLE-only inputs keep tight tolerances: there the only difference is
%   double rounding order.

if nargin < 4
    cRef = [];
end

anySingle = isa(frame,'single') || isa(freshness,'single') || isa(template,'single');
if anySingle
    cTol = 2.5e-4;          % ~5x the differences observed on real SLAP2 frames
    rTol = 2.5e-4;
    mFloor = 1e-2;          % px; 2.5 nm at 250 nm/px
    mCap = 0.25;            % px; gross-error guard (integer peak is checked separately)
else
    cTol = 5e-10;
    rTol = 5e-10;
    mFloor = 5e-9;
    mCap = 1e-3;
end

% Derive the motion tolerance from the reference surface's peak curvature.
% With the ratio formula dX = (1-q)/(1+q)/2, q = a/b, a = C0-Cm, b = C0-Cp,
% a perturbation of at most eps on each C value changes dX by at most
% 2*eps/(a+b) <= eps/min(a,b) to first order. Use twice that bound (margin
% for second-order terms and for the two axes sharing C0) with eps = cTol.
curvature = NaN;
if ~isempty(cRef) && ismatrix(cRef) && all(size(cRef) >= 3)
    [~,I] = max(cRef(:));
    [rr,cc] = ind2sub(size(cRef),I);
    if rr > 1 && rr < size(cRef,1) && cc > 1 && cc < size(cRef,2)
        c0 = cRef(rr,cc);
        drops = [c0-cRef(rr-1,cc), c0-cRef(rr+1,cc), c0-cRef(rr,cc-1), c0-cRef(rr,cc+1)];
        drops = drops(isfinite(drops) & drops > 0);
        if ~isempty(drops)
            curvature = min(drops);
        end
    end
end

if isfinite(curvature) && curvature > 0
    mDerived = 2*cTol/curvature;
else
    % Peak on the search boundary or degenerate surface: no subpixel step is
    % taken by either implementation, so only the floor applies.
    mDerived = 0;
end
mTol = min(mCap, max(mFloor, mDerived));

detail = struct('anySingle',anySingle,'peakCurvature',curvature, ...
    'motionTolFloor',mFloor,'motionTolDerived',mDerived,'motionTolCap',mCap);
end
