function tests = test_xcorr2_nans_weighted_mex
tests = functiontests(localfunctions);
end

function testRandomizedMexMatchesFastAcrossProductionClasses(testCase)
assumeTrue(testCase,exist('xcorr2_nans_weighted_mex','file') == 3, ...
    'Optional MEX binary is not built on this machine.');

classDefs = { ...
    'double','double','double'; ...
    'single','single','single'; ...
    'single','single','double'};

rng(23);
for caseIx = 1:size(classDefs,1)
    for iteration = 1:8
        sz = [35+randi(20), 41+randi(20)];
        frame0 = randn(sz);
        template0 = randn(sz);
        freshness0 = 0.1 + 4*rand(sz);
        frame0(rand(sz)<0.16) = nan;
        template0(rand(sz)<0.12) = nan;

        frame = cast(frame0,classDefs{caseIx,1});
        freshness = cast(freshness0,classDefs{caseIx,2});
        template = cast(template0,classDefs{caseIx,3});
        center = [randi(5)-3; randi(5)-3];
        radius = randi([1 5]);

        [mRef,rRef,cRef] = xcorr2_nans_weighted_fast( ...
            frame,freshness,template,center,radius);
        [mMex,rMex,cMex] = xcorr2_nans_weighted_mex( ...
            frame,freshness,template,center,double(radius));

        verifyEqual(testCase,isnan(cMex),isnan(cRef));
        [~,iRef] = max(cRef(:));
        [~,iMex] = max(cMex(:));
        verifyEqual(testCase,iMex,iRef,'Peak index must be identical.');

        if any(strcmp(classDefs(caseIx,:),'single'))
            cTol = 5e-5; rTol = 5e-5; mTol = 5e-4;
        else
            cTol = 5e-10; rTol = 5e-10; mTol = 5e-9;
        end
        verifyEqual(testCase,cMex,cRef,'AbsTol',cTol);
        verifyEqual(testCase,rMex,rRef,'AbsTol',rTol);
        verifyEqual(testCase,mMex,mRef,'AbsTol',mTol);
    end
end
end
