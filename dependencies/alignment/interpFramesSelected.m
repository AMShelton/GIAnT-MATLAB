function [IM, vIM] = interpFramesSelected(M1, viewC, viewR, freshness, outputLinearIdx)
%INTERPFRAMESSELECTED Interpolate only requested output pixels.
%
% [IM,VIM] = interpFramesSelected(M1,VIEWC,VIEWR,FRESHNESS,IDXS)
% evaluates the same freshness-weighted bilinear interpolation used by
% interpFrames.m, but only at linear output pixel indices IDXS.  This is a
% performance optimization for sparse high-resolution SLAP2 extraction: the
% scientific interpolation and variance-factor equations are unchanged.
%
% M1        : input image, rows x cols x channels
% viewC     : output-column sampling coordinates (row vector)
% viewR     : output-row sampling coordinates (column vector)
% freshness : rows x cols effective sample-count image
% IDXS      : linear indices in output space [numel(viewR), numel(viewC)]
%
% IM  : numel(IDXS) x channels
% vIM : numel(IDXS) x 1

nRowsOut = numel(viewR);
nColsOut = numel(viewC);
outputLinearIdx = outputLinearIdx(:);

if isempty(outputLinearIdx)
    IM = zeros(0, size(M1,3), 'like', M1);
    vIM = zeros(0, 1, 'like', freshness);
    return
end

[outR, outC] = ind2sub([nRowsOut nColsOut], outputLinearIdx);
qR = viewR(outR);
qC = viewC(outC);

r0 = floor(qR); r1 = ceil(qR);
c0 = floor(qC); c1 = ceil(qC);

fr = mod(qR,1);
fc = mod(qC,1);
w1 = (1-fc).*(1-fr);
w2 = fc.*(1-fr);
w3 = (1-fc).*fr;
w4 = fc.*fr;

[a1,f1] = samplePairs(M1, freshness, r0, c0);
[a2,f2] = samplePairs(M1, freshness, r0, c1);
[a3,f3] = samplePairs(M1, freshness, r1, c0);
[a4,f4] = samplePairs(M1, freshness, r1, c1);

den = w1.*f1 + w2.*f2 + w3.*f3 + w4.*f4;
IM = (w1.*f1.*a1 + w2.*f2.*a2 + w3.*f3.*a3 + w4.*f4.*a4) ./ den;
vIM = 1./den;
vIM(isinf(vIM)) = nan;
end

function [A,F] = samplePairs(M, freshness, rr, cc)
% Sample corresponding row/column pairs rather than a full Cartesian grid.
[nRows,nCols,nChannels] = size(M);
valid = rr>=1 & rr<=nRows & cc>=1 & cc<=nCols;

A = nan(numel(rr), nChannels, 'like', M);
F = nan(numel(rr), 1, 'like', freshness);
if ~any(valid)
    return
end

lin = sub2ind([nRows nCols], rr(valid), cc(valid));
Mflat = reshape(M, nRows*nCols, nChannels);
Fflat = freshness(:);
A(valid,:) = Mflat(lin,:);
F(valid) = Fflat(lin);
end
