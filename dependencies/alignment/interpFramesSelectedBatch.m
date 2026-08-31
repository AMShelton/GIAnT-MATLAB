function [IM, vIM] = interpFramesSelectedBatch(M, viewC, viewR, freshness, outputLinearIdx, motionC, motionR, frameBatchSize)
%INTERPFRAMESSELECTEDBATCH Batched sparse bilinear interpolation.
%
% This is numerically equivalent to calling interpFramesSelected once per
% frame, but it vectorizes coordinate generation and neighbor gathering over
% small frame batches. It is intended for the 200-Hz SLAP2 SILo pathway,
% where only a small fraction of the registered FOV is needed.
%
% Inputs
%   M                 rows x cols x channels x frames
%   viewC, viewR      base output sampling coordinates (without motion)
%   freshness         rows x cols x frames
%   outputLinearIdx   requested linear output pixels in
%                     [numel(viewR), numel(viewC)]
%   motionC, motionR  one scalar shift per frame
%   frameBatchSize    internal vectorization batch size (default 64)
%
% Outputs
%   IM                 selectedPixels x channels x frames
%   vIM                selectedPixels x frames
%
% The same four-neighbor freshness-weighted interpolation is used as in
% interpFramesSelected/interpFrames. Invalid neighbors remain NaN, including
% the original MATLAB 0*NaN behavior at image boundaries.

if nargin < 8 || isempty(frameBatchSize)
    frameBatchSize = 64;
end
frameBatchSize = max(1, round(double(frameBatchSize)));

nRowsOut = numel(viewR);
nColsOut = numel(viewC);
outputLinearIdx = outputLinearIdx(:);
nSelected = numel(outputLinearIdx);
nFrames = size(M,4);
nChannels = size(M,3);

if numel(motionC) ~= nFrames || numel(motionR) ~= nFrames
    error('interpFramesSelectedBatch:MotionLengthMismatch', ...
        'motionC and motionR must have one value per input frame.');
end

if any(~isfinite(outputLinearIdx)) || ...
        any(outputLinearIdx < 1) || ...
        any(outputLinearIdx > nRowsOut*nColsOut) || ...
        any(outputLinearIdx ~= round(outputLinearIdx))
    error('interpFramesSelectedBatch:InvalidOutputIndex', ...
        'outputLinearIdx contains indices outside the output image bounds.');
end

IM = nan(nSelected,nChannels,nFrames,'like',M);
vIM = nan(nSelected,nFrames,'like',freshness);
if isempty(outputLinearIdx) || nFrames == 0
    return
end

[outR,outC] = ind2sub([nRowsOut nColsOut],outputLinearIdx);
baseR = viewR(outR); baseR = baseR(:);
baseC = viewC(outC); baseC = baseC(:);
motionC = reshape(motionC,1,[]);
motionR = reshape(motionR,1,[]);

for firstFrame = 1:frameBatchSize:nFrames
    lastFrame = min(nFrames,firstFrame+frameBatchSize-1);
    fIxs = firstFrame:lastFrame;
    nBatchFrames = numel(fIxs);

    qR = baseR + motionR(fIxs);
    qC = baseC + motionC(fIxs);

    r0 = floor(qR); r1 = ceil(qR);
    c0 = floor(qC); c1 = ceil(qC);

    fr = mod(qR,1);
    fc = mod(qC,1);
    w1 = (1-fc).*(1-fr);
    w2 = fc.*(1-fr);
    w3 = (1-fc).*fr;
    w4 = fc.*fr;

    Mb = M(:,:,:,fIxs);
    Fb = freshness(:,:,fIxs);

    [a1,f1] = sampleBatchPairs(Mb,Fb,r0,c0);
    [a2,f2] = sampleBatchPairs(Mb,Fb,r0,c1);
    [a3,f3] = sampleBatchPairs(Mb,Fb,r1,c0);
    [a4,f4] = sampleBatchPairs(Mb,Fb,r1,c1);

    den = w1.*f1 + w2.*f2 + w3.*f3 + w4.*f4;

    wf1 = reshape(w1.*f1,[nSelected 1 nBatchFrames]);
    wf2 = reshape(w2.*f2,[nSelected 1 nBatchFrames]);
    wf3 = reshape(w3.*f3,[nSelected 1 nBatchFrames]);
    wf4 = reshape(w4.*f4,[nSelected 1 nBatchFrames]);

    numer = wf1.*a1 + wf2.*a2 + wf3.*a3 + wf4.*a4;
    IM(:,:,fIxs) = numer ./ reshape(den,[nSelected 1 nBatchFrames]);

    vb = 1./den;
    vb(isinf(vb)) = nan;
    vIM(:,fIxs) = vb;
end
end

function [A,F] = sampleBatchPairs(M,freshness,rr,cc)
% Sample corresponding row/column pairs for multiple frames at once.

[nRows,nCols,nChannels,nFrames] = size(M);
nSelected = size(rr,1);

if ~isequal(size(rr),size(cc)) || size(rr,2) ~= nFrames
    error('interpFramesSelectedBatch:CoordinateSizeMismatch', ...
        'Coordinate arrays must be selectedPixels x frames.');
end

valid = rr>=1 & rr<=nRows & cc>=1 & cc<=nCols;

A = nan(nSelected,nChannels,nFrames,'like',M);
F = nan(nSelected,nFrames,'like',freshness);
if ~any(valid(:))
    return
end

nPx = nRows*nCols;
validVec = valid(:);

rrValid = rr(valid);
ccValid = cc(valid);
spatialIdx = sub2ind([nRows nCols],rrValid,ccValid);

% MATLAB linearizes selectedPixels x frames column-by-column.
frameIdxAll = repelem((1:nFrames)',nSelected);
frameIdx = frameIdxAll(validVec);

freshFlat = freshness(:);
freshLin = spatialIdx + (frameIdx-1)*nPx;
F(valid) = freshFlat(freshLin);

for ch = 1:nChannels
    yLin = spatialIdx + (ch-1)*nPx + (frameIdx-1)*nPx*nChannels;
    tmp = nan(nSelected,nFrames,'like',M);
    tmp(valid) = M(yLin);
    A(:,ch,:) = reshape(tmp,[nSelected 1 nFrames]);
end
end
