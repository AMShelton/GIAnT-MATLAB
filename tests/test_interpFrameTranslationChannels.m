function tests = test_interpFrameTranslationChannels
tests = functiontests(localfunctions);
end

function testTwoChannelsMatchSeparateReferenceCalls(testCase)
rng(21);
M = rand(28,35,2);
freshness = 0.4 + rand(28,35);
M(rand(size(M))<0.05) = nan;

maxshift = 5;
baseViewC = (1:(size(M,2)+2*maxshift))-maxshift;
baseViewR = ((1:(size(M,1)+2*maxshift))-maxshift)';
motionC = -2.37;
motionR = 1.62;

[Afast,Vfast] = interpFrameTranslationChannels( ...
    M,baseViewC,baseViewR,motionC,motionR,freshness);

[A1,V1] = interpFrame(M(:,:,1),baseViewC+motionC,baseViewR+motionR,freshness);
[A2,V2] = interpFrame(M(:,:,2),baseViewC+motionC,baseViewR+motionR,freshness);

verifyEqual(testCase,Afast(:,:,1),A1,'AbsTol',1e-12);
verifyEqual(testCase,Afast(:,:,2),A2,'AbsTol',1e-12);
verifyEqual(testCase,Vfast,V1,'AbsTol',1e-12);
verifyEqual(testCase,Vfast,V2,'AbsTol',1e-12);
end

function testSingleChannelMatchesReference(testCase)
rng(22);
M = rand(19,24);
freshness = 0.25 + rand(19,24);

baseViewC = -3:27;
baseViewR = (-3:22)';
motionC = 0.41;
motionR = -0.73;

[Afast,Vfast] = interpFrameTranslationChannels( ...
    M,baseViewC,baseViewR,motionC,motionR,freshness);
[Aref,Vref] = interpFrame(M,baseViewC+motionC,baseViewR+motionR,freshness);

verifyEqual(testCase,Afast,Aref,'AbsTol',1e-12);
verifyEqual(testCase,Vfast,Vref,'AbsTol',1e-12);
end
