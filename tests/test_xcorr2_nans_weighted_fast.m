function tests = test_xcorr2_nans_weighted_fast
tests = functiontests(localfunctions);
end

function testMatchesReferenceAtZeroCenter(testCase)
rng(11);
frame = rand(41,53);
template = rand(41,53);
freshness = 0.5 + 3*rand(41,53);

frame(rand(size(frame))<0.12) = nan;
template(rand(size(template))<0.08) = nan;

[mRef,rRef] = xcorr2_nans_weighted(frame,freshness,template,[0;0],4);
[mFast,rFast,cFast] = xcorr2_nans_weighted_fast(frame,freshness,template,[0;0],4);
cRef = referenceSurface(frame,freshness,template,[0;0],4);

verifyEqual(testCase,mFast,mRef,'AbsTol',1e-12);
verifyEqual(testCase,rFast,rRef,'AbsTol',1e-12);
verifyEqual(testCase,cFast,cRef,'AbsTol',1e-12);
end

function testMatchesReferenceAtNonzeroCenter(testCase)
rng(12);
frame = rand(37,45);
template = rand(37,45);
freshness = 1 + rand(37,45);

frame(rand(size(frame))<0.1) = nan;
template(rand(size(template))<0.1) = nan;

center = [2;-1];
[mRef,rRef] = xcorr2_nans_weighted(frame,freshness,template,center,3);
[mFast,rFast,cFast] = xcorr2_nans_weighted_fast(frame,freshness,template,center,3);
cRef = referenceSurface(frame,freshness,template,center,3);

verifyEqual(testCase,mFast,mRef,'AbsTol',1e-12);
verifyEqual(testCase,rFast,rRef,'AbsTol',1e-12);
verifyEqual(testCase,cFast,cRef,'AbsTol',1e-12);
end

function testRandomizedRegressionAgainstReference(testCase)
rng(13);
for iteration = 1:12
    sz = [25+randi(20), 31+randi(20)];
    frame = randn(sz);
    template = randn(sz);
    freshness = 0.1 + 4*rand(sz);
    frame(rand(sz)<0.18) = nan;
    template(rand(sz)<0.13) = nan;
    center = [randi(5)-3; randi(5)-3];
    dShift = randi([1 5]);

    [mRef,rRef] = xcorr2_nans_weighted(frame,freshness,template,center,dShift);
    [mFast,rFast,cFast] = xcorr2_nans_weighted_fast(frame,freshness,template,center,dShift);
    cRef = referenceSurface(frame,freshness,template,center,dShift);

    verifyEqual(testCase,mFast,mRef,'AbsTol',1e-11);
    verifyEqual(testCase,rFast,rRef,'AbsTol',1e-11);
    verifyEqual(testCase,cFast,cRef,'AbsTol',1e-11);
end
end

function testRowAndColumnShiftCenterAgree(testCase)
rng(14);
frame = rand(29,34);
template = rand(29,34);
freshness = 0.5 + rand(29,34);
frame(rand(size(frame))<0.05) = nan;
template(rand(size(template))<0.05) = nan;

[mCol,rCol,cCol] = xcorr2_nans_weighted_fast(frame,freshness,template,[1;-2],3);
[mRow,rRow,cRow] = xcorr2_nans_weighted_fast(frame,freshness,template,[1 -2],3);
verifyEqual(testCase,mRow,mCol,'AbsTol',0);
verifyEqual(testCase,rRow,rCol,'AbsTol',0);
verifyEqual(testCase,cRow,cCol,'AbsTol',0);
end

function C = referenceSurface(frame,freshness,template,shiftsCenter,dShift)
% Independent copy of the legacy candidate statistic for regression testing.
sz = size(template);
dShift = round(dShift(1));
template = circshift(template,shiftsCenter(:));
[Fr0,Fc0] = find(~isnan(frame));
shifts = -dShift:dShift;
C = nan(numel(shifts),numel(shifts));
for drix = 1:numel(shifts)
    for dcix = 1:numel(shifts)
        Tr = Fr0 + shifts(drix);
        Tc = Fc0 + shifts(dcix);
        valid = Tr>=1 & Tr<=sz(1) & Tc>=1 & Tc<=sz(2);
        Fr = Fr0(valid); Fc = Fc0(valid); Tr = Tr(valid); Tc = Tc(valid);
        T = template(sub2ind(sz,Tr,Tc));
        sel = ~isnan(T);
        T = T(sel);
        indsF = sub2ind(sz,Fr(sel),Fc(sel));
        F = frame(indsF);
        Ff = freshness(indsF);
        if isempty(F)
            continue
        end
        sFT = sum(Ff.*(F-mean(F)).*(T-mean(T)));
        sT = mean((T-mean(T)).^2);
        sF = sum(Ff.*(F-mean(F)).^2);
        C(drix,dcix) = sFT./sqrt(sT.*sF.*sum(Ff));
    end
end
end
