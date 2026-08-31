function tests = test_interpFramesSelected
tests = functiontests(localfunctions);
end

function selectedMatchesFull(testCase)
rng(1);
M = rand(37,53,2);
fresh = 0.5 + rand(37,53);
M(rand(37,53)<0.08,:,:) = nan;
fresh(isnan(M(:,:,1))) = nan;

viewC = (1:57) - 2.37;
viewR = (1:41)' - 1.62;
[fullIM,fullV] = interpFrames(M,viewC,viewR,fresh);

idx = randperm(numel(fullV),min(500,numel(fullV)))';
[selIM,selV] = interpFramesSelected(M,viewC,viewR,fresh,idx);

fullFlat = reshape(fullIM,[],size(fullIM,3));
verifyEqual(testCase,selIM,fullFlat(idx,:),'AbsTol',1e-12);
verifyEqual(testCase,selV,fullV(idx),'AbsTol',1e-12);
end
