function [motion,R,C] = xcorr2_nans_weighted_fast(frame,freshness,template,shiftsCenter,dShift)
%XCORR2_NANS_WEIGHTED_FAST Allocation-efficient equivalent correlation.
%
% Preserves xcorr2_nans_weighted's statistic and subpixel peak calculation,
% but avoids FIND/SUB2IND coordinate rebuilding for every candidate shift.
% Each shift is evaluated using direct overlapping rectangular slices.
%
% Optional third output C exposes the correlation surface for regression QC.

sz = size(template);
if ~isequal(size(frame),sz) || ~isequal(size(freshness),sz)
    error('xcorr2_nans_weighted_fast:SizeMismatch', ...
        'frame, freshness, and template must have identical 2-D size.');
end

dShift = round(dShift(1));
template = circshift(template,shiftsCenter);
shifts = -dShift:dShift;
nShifts = numel(shifts);
C = nan(nShifts,nShifts);

nRows = sz(1);
nCols = sz(2);

for drix = 1:nShifts
    dr = shifts(drix);
    if dr >= 0
        fRows = 1:(nRows-dr);
        tRows = (1+dr):nRows;
    else
        fRows = (1-dr):nRows;
        tRows = 1:(nRows+dr);
    end

    for dcix = 1:nShifts
        dc = shifts(dcix);
        if dc >= 0
            fCols = 1:(nCols-dc);
            tCols = (1+dc):nCols;
        else
            fCols = (1-dc):nCols;
            tCols = 1:(nCols+dc);
        end

        Fblock = frame(fRows,fCols);
        Tblock = template(tRows,tCols);
        valid = ~isnan(Fblock) & ~isnan(Tblock);

        if ~any(valid,'all')
            continue
        end

        F = Fblock(valid);
        T = Tblock(valid);
        FfBlock = freshness(fRows,fCols);
        Ff = FfBlock(valid);

        % Same unweighted means and freshness-weighted covariance/variance
        % used by xcorr2_nans_weighted.m.
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
