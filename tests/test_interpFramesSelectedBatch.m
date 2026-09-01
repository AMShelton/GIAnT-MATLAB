function tests = test_interpFramesSelectedBatch
tests = functiontests(localfunctions);
end

function testBatchMatchesFramewise(testCase)
rng(4);

nRows = 27;
nCols = 33;
nChannels = 2;
nFrames = 11;
maxshift = 4;

M = rand(nRows,nCols,nChannels,nFrames);
freshness = 0.25 + rand(nRows,nCols,nFrames);

viewR = ((1:(nRows+2*maxshift))-maxshift)';
viewC =  (1:(nCols+2*maxshift))-maxshift;

motionR = linspace(-0.71,0.83,nFrames);
motionC = linspace(0.62,-0.45,nFrames);

nOutRows = numel(viewR);
nOutCols = numel(viewC);
idx = unique([1; 2; 19; 103; round(linspace(1,nOutRows*nOutCols,181))']);

[batchIM,batchV] = interpFramesSelectedBatch( ...
    M,viewC,viewR,freshness,idx,motionC,motionR,4);

refIM = nan(numel(idx),nChannels,nFrames);
refV = nan(numel(idx),nFrames);
for t = 1:nFrames
    [refIM(:,:,t),refV(:,t)] = interpFramesSelected( ...
        M(:,:,:,t),viewC+motionC(t),viewR+motionR(t),freshness(:,:,t),idx);
end

verifyEqual(testCase,batchIM,refIM,'AbsTol',1e-12);
verifyEqual(testCase,batchV,refV,'AbsTol',1e-12);
end

function testSingleFrame(testCase)
M = rand(12,15,1,1);
F = ones(12,15,1);
viewR = (1:16)';
viewC = 1:19;
idx = [1; 5; 43; 120; 250];

[a,b] = interpFramesSelectedBatch(M,viewC-2,viewR-2,F,idx,0.25,-0.6,32);
[c,d] = interpFramesSelected(M,viewC-2+0.25,viewR-2-0.6,F(:,:,1),idx);

verifyEqual(testCase,a,c,'AbsTol',1e-12);
verifyEqual(testCase,b,d,'AbsTol',1e-12);
end

function testFinalSingletonBatch(testCase)
rng(7);
M = rand(10,13,2,5);
F = 0.5 + rand(10,13,5);
viewR = (1:14)';
viewC = 1:17;
idx = [2; 31; 119];
motionC = [0.1 -0.2 0.3 -0.1 0.25];
motionR = [-0.2 0.15 -0.35 0.05 0.4];

% batch size 4 forces the last internal batch to contain exactly one frame.
[a,b] = interpFramesSelectedBatch(M,viewC-2,viewR-2,F,idx,motionC,motionR,4);

c = nan(numel(idx),2,5);
d = nan(numel(idx),5);
for k = 1:5
    [c(:,:,k),d(:,k)] = interpFramesSelected( ...
        M(:,:,:,k),viewC-2+motionC(k),viewR-2+motionR(k),F(:,:,k),idx);
end
verifyEqual(testCase,a,c,'AbsTol',1e-12);
verifyEqual(testCase,b,d,'AbsTol',1e-12);
end

function testOneSelectedPixel(testCase)
M = rand(8,9,1,3);
F = ones(8,9,3);
viewR = (1:10)';
viewC = 1:11;
idx = 27;
mc = [0.2 -0.1 0.4];
mr = [-0.3 0.25 0.1];
[a,b] = interpFramesSelectedBatch(M,viewC-1,viewR-1,F,idx,mc,mr,2);
c = nan(1,1,3); d = nan(1,3);
for k = 1:3
    [c(:,:,k),d(:,k)] = interpFramesSelected( ...
        M(:,:,:,k),viewC-1+mc(k),viewR-1+mr(k),F(:,:,k),idx);
end
verifyEqual(testCase,a,c,'AbsTol',1e-12);
verifyEqual(testCase,b,d,'AbsTol',1e-12);
end
