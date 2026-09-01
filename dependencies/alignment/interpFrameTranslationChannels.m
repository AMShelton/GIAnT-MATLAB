function [IM,vIM] = interpFrameTranslationChannels(M,baseViewC,baseViewR,motionC,motionR,freshness)
%INTERPFRAMETRANSLATIONCHANNELS Translation-specialized interpFrame.
%
% This implements the same four-neighbor freshness-weighted bilinear
% interpolation used by interpFrame.m. baseViewC/baseViewR are the regular
% output sampling vectors and motionC/motionR are scalar translations.
% For multi-channel M, coordinate/freshness lookup is performed once and
% reused for every channel.

if ~isscalar(motionC) || ~isscalar(motionR)
    error('interpFrameTranslationChannels:NonScalarMotion', ...
        'motionC and motionR must be scalar translations.');
end

baseViewC = reshape(baseViewC,1,[]);
baseViewR = reshape(baseViewR,[],1);
viewC = baseViewC + motionC;
viewR = baseViewR + motionR;

sz = size(M);
nRows = sz(1);
nCols = sz(2);

fracC = mod(viewC(1),1);
fracR = mod(viewR(1),1);
c1 = (1-fracC).*(1-fracR);
c2 = fracC.*(1-fracR);
c3 = (1-fracC).*fracR;
c4 = fracC.*fracR;

rFloor = floor(viewR);
rCeil  = ceil(viewR);
cFloor = floor(viewC);
cCeil  = ceil(viewC);

[a1,f1] = gatherNeighbor(M,freshness,rFloor,cFloor,nRows,nCols);
[a2,f2] = gatherNeighbor(M,freshness,rFloor,cCeil, nRows,nCols);
[a3,f3] = gatherNeighbor(M,freshness,rCeil, cFloor,nRows,nCols);
[a4,f4] = gatherNeighbor(M,freshness,rCeil, cCeil, nRows,nCols);

den = c1*f1 + c2*f2 + c3*f3 + c4*f4;
IM = (c1*f1.*a1 + c2*f2.*a2 + c3*f3.*a3 + c4*f4.*a4) ./ den;

vIM = 1./den;
vIM(isinf(vIM)) = nan;
end

function [A,F] = gatherNeighbor(M,freshness,rr,cc,nRows,nCols)
rr = reshape(rr,[],1);
cc = reshape(cc,1,[]);

rInvalid = rr<1 | rr>nRows;
cInvalid = cc<1 | cc>nCols;

rrSafe = rr;
ccSafe = cc;
rrSafe(rInvalid) = 1;
ccSafe(cInvalid) = 1;

A = M(rrSafe,ccSafe,:);
F = freshness(rrSafe,ccSafe);

A(rInvalid,:,:) = nan;
A(:,cInvalid,:) = nan;
F(rInvalid,:) = nan;
F(:,cInvalid) = nan;
end
