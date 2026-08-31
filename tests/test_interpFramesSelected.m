function tests = test_interpFramesSelected
tests = functiontests(localfunctions);
end

function testSparseMatchesFullInterpolation(testCase)
rng(1);

nRows = 23;
nCols = 31;
nChannels = 2;
M = rand(nRows,nCols,nChannels);
freshness = 0.5 + rand(nRows,nCols);

% Mirror GIAnT's normal orientation: viewR column, viewC row.
maxshift = 3;
viewR = ((1:(nRows+2*maxshift))-maxshift)';
viewC =  (1:(nCols+2*maxshift))-maxshift;

motionR = 0.37;
motionC = -0.61;

% Compute the full reference with the original GIAnT interpolator.
[fullIM, fullV] = interpFrames(M, viewC+motionC, viewR+motionR, freshness);

% Select an irregular subset including boundary/out-of-bounds regions.
outRows = numel(viewR);
outCols = numel(viewC);
idx = unique([1; 2; 17; 100; round(linspace(1,outRows*outCols,127))']);

[sparseIM, sparseV] = interpFramesSelected( ...
    M, viewC+motionC, viewR+motionR, freshness, idx);

fullIMflat = reshape(fullIM, outRows*outCols, nChannels);
fullVflat = fullV(:);

verifyEqual(testCase, sparseIM, fullIMflat(idx,:), 'AbsTol', 1e-12);
verifyEqual(testCase, sparseV, fullVflat(idx), 'AbsTol', 1e-12);
end

function testRowColumnOrientationDoesNotExpand(testCase)
M = rand(10,12,1);
freshness = ones(10,12);
viewR = (1:14)';       % column
viewC = 1:16;          % row
idx = [1; 7; 31; 100; 180];

[IM,V] = interpFramesSelected(M,viewC-2.25,viewR-1.5,freshness,idx);

verifySize(testCase, IM, [numel(idx) 1]);
verifySize(testCase, V, [numel(idx) 1]);
end
