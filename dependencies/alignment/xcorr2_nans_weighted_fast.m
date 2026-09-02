function [motion,R,C] = xcorr2_nans_weighted_fast(frame,freshness,template,shiftsCenter,dShift)
%XCORR2_NANS_WEIGHTED_FAST Exact low-allocation weighted local correlation.
%
% Preserves xcorr2_nans_weighted's statistic, candidate ordering, and
% subpixel peak calculation while reducing repeated work in the hot loop:
%   * a zero shiftsCenter no longer copies the full template via CIRCSHIFT;
%   * NaN masks are computed once per input image, not once per candidate;
%   * overlap row/column index vectors are cached for repeated calls with the
%     same image size and search radius (the common MultiRoiRegistration case).
%
% Optional third output C exposes the correlation surface for regression QC.

if ~ismatrix(frame) || ~ismatrix(freshness) || ~ismatrix(template)
    error('xcorr2_nans_weighted_fast:Expected2D', ...
        'frame, freshness, and template must be 2-D arrays.');
end
sz = size(template);
if ~isequal(size(frame),sz) || ~isequal(size(freshness),sz)
    error('xcorr2_nans_weighted_fast:SizeMismatch', ...
        'frame, freshness, and template must have identical 2-D size.');
end
if numel(shiftsCenter) ~= 2 || any(~isfinite(shiftsCenter(:))) || ...
        any(shiftsCenter(:) ~= round(shiftsCenter(:)))
    error('xcorr2_nans_weighted_fast:InvalidShiftCenter', ...
        'shiftsCenter must contain two finite integer pixel offsets.');
end
if isempty(dShift) || ~isnumeric(dShift) || ~isfinite(dShift(1)) || dShift(1) < 0
    error('xcorr2_nans_weighted_fast:InvalidShiftRadius', ...
        'dShift must be a finite nonnegative scalar.');
end

shiftsCenter = shiftsCenter(:);
dShift = round(dShift(1));

% MultiRoiRegistration currently calls this hot path with [0;0]. Avoiding a
% no-op CIRCSHIFT prevents one full image allocation/copy per registered frame.
if any(shiftsCenter ~= 0)
    template = circshift(template,shiftsCenter);
end

[shifts,fRowsByShift,tRowsByShift,fColsByShift,tColsByShift] = ...
    getShiftGeometry(sz,dShift);
nShifts = numel(shifts);
C = nan(nShifts,nShifts);

% These masks are invariant across every candidate shift within this call.
% The previous fast implementation repeated ISNAN over two large numeric
% blocks for each of (2*dShift+1)^2 candidates.
frameValid = ~isnan(frame);
templateValid = ~isnan(template);

for drix = 1:nShifts
    fRows = fRowsByShift{drix};
    tRows = tRowsByShift{drix};

    for dcix = 1:nShifts
        fCols = fColsByShift{dcix};
        tCols = tColsByShift{dcix};

        valid = frameValid(fRows,fCols) & templateValid(tRows,tCols);
        if ~any(valid,'all')
            continue
        end

        % Keep the arithmetic below intentionally identical to
        % xcorr2_nans_weighted / the previous fast implementation so this
        % optimization changes execution cost, not the correlation statistic.
        Fblock = frame(fRows,fCols);
        Tblock = template(tRows,tCols);
        F = Fblock(valid);
        T = Tblock(valid);
        FfBlock = freshness(fRows,fCols);
        Ff = FfBlock(valid);

        mF = mean(F);
        mT = mean(T);
        dF = F-mF;
        dT = T-mT;

        sFT = sum(Ff.*dF.*dT);
        sT = mean(dT.^2);
        sF = sum(Ff.*dF.^2);
        C(drix,dcix) = sFT./sqrt(sT.*sF.*sum(Ff));
    end
end

[maxval,I] = max(C(:));
[rr,cc] = ind2sub(size(C),I);
R = maxval;

if rr>1 && rr<nShifts && cc>1 && cc<nShifts
    ratioR = min(1e6,(C(rr,cc)-C(rr-1,cc))/(C(rr,cc)-C(rr+1,cc)));
    dR = (1-ratioR)/(1+ratioR)/2;

    ratioC = min(1e6,(C(rr,cc)-C(rr,cc-1))/(C(rr,cc)-C(rr,cc+1)));
    dC = (1-ratioC)/(1+ratioC)/2;

    motion = -shiftsCenter' + [shifts(rr)-dR,shifts(cc)-dC];
else
    motion = -shiftsCenter' + [shifts(rr),shifts(cc)];
end

motion = -motion;

if any(isnan(motion))
    error('xcorr2_nans_weighted_fast:NaNMotion', ...
        'Computed motion contains NaN.');
end
end


function [shifts,fRows,tRows,fCols,tCols] = getShiftGeometry(sz,dShift)
%GETSHIFTGEOMETRY Cache overlap vectors for the repeated registration calls.
persistent cachedSize cachedDShift cachedShifts cachedFRows cachedTRows cachedFCols cachedTCols

if ~isempty(cachedSize) && isequal(cachedSize,sz) && isequal(cachedDShift,dShift)
    shifts = cachedShifts;
    fRows = cachedFRows;
    tRows = cachedTRows;
    fCols = cachedFCols;
    tCols = cachedTCols;
    return
end

nRows = sz(1);
nCols = sz(2);
shifts = -dShift:dShift;
nShifts = numel(shifts);
fRows = cell(1,nShifts);
tRows = cell(1,nShifts);
fCols = cell(1,nShifts);
tCols = cell(1,nShifts);

for ix = 1:nShifts
    d = shifts(ix);
    if d >= 0
        fRows{ix} = 1:(nRows-d);
        tRows{ix} = (1+d):nRows;
        fCols{ix} = 1:(nCols-d);
        tCols{ix} = (1+d):nCols;
    else
        fRows{ix} = (1-d):nRows;
        tRows{ix} = 1:(nRows+d);
        fCols{ix} = (1-d):nCols;
        tCols{ix} = 1:(nCols+d);
    end
end

cachedSize = sz;
cachedDShift = dShift;
cachedShifts = shifts;
cachedFRows = fRows;
cachedTRows = tRows;
cachedFCols = fCols;
cachedTCols = tCols;
end
