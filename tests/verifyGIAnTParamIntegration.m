function verifyGIAnTParamIntegration_fixed()
%VERIFYGIANTPARAMINTEGRATION_FIXED Sanity checks for the selectable SILo backend.
%
% Run from a MATLAB session in which the updated GIAnT repo is first on path.
% This does not run motion correction or source extraction.

fprintf('Checking MATLAB parser/code analyzer...\n');
filesToCheck = {'setParams.m','optionsGUI.m'};
for i = 1:numel(filesToCheck)
    fn = which(filesToCheck{i});
    assert(~isempty(fn), 'Could not resolve %s on MATLAB path.', filesToCheck{i});

    msgs = checkcode(fn,'-id');

    % checkcode returns a struct array. Accessing msgs.id directly produces a
    % comma-separated list when more than one message exists, so do not pass
    % it directly to string(). Work with a cell array of IDs instead.
    if isempty(msgs)
        parseLike = false(0,1);
    else
        ids = {msgs.id};
        parseLike = cellfun(@(id) ...
            contains(id,'PARSE','IgnoreCase',true) || ...
            contains(id,'SYNTAX','IgnoreCase',true), ids);
    end

    if any(parseLike)
        disp(msgs(parseLike));
        error('verifyGIAnTParamIntegration:ParserIssue', ...
            'MATLAB code analyzer reported a parser/syntax issue in %s.', fn);
    end
    fprintf('  %s\n', fn);
end

fprintf('Checking MultiRoiRegistration parameter completeness...\n');
m = setParams('MultiRoiRegistration', struct());

requiredMoco = { ...
    'alignHz','maxshift','clipShift','alpha','nWorkers', ...
    'overwriteExisting','refStackTemplate','isReVolt', ...
    'includeIntegrationROIs','varFacChunkXY', ...
    'registrationBlockFrames','registrationBlockMemoryGB', ...
    'reuseSlap2Reader','useFastWeightedXcorr','useFastInterpolation'};

missing = requiredMoco(~isfield(m,requiredMoco));
assert(isempty(missing), ...
    'Missing MultiRoiRegistration parameters: %s', strjoin(missing,', '));

% Verify the authoritative defaults from the untouched optimized GIAnT setParams.
assert(m.varFacChunkXY == 128, ...
    'Unexpected varFacChunkXY default.');
assert(m.registrationBlockFrames == 128, ...
    'Unexpected registrationBlockFrames default.');
assert(m.registrationBlockMemoryGB == 4, ...
    'Unexpected registrationBlockMemoryGB default.');
assert(isequal(m.reuseSlap2Reader,true), ...
    'Unexpected reuseSlap2Reader default.');
assert(isequal(m.useFastWeightedXcorr,true), ...
    'Unexpected useFastWeightedXcorr default.');
assert(isequal(m.useFastInterpolation,true), ...
    'Unexpected useFastInterpolation default.');

fprintf('Checking native SILo backend defaults...\n');
s = setParams('SILo', struct());
assert(strcmp(s.sourceDetectionMethod,'silo'), ...
    'Native SILo is not the default source-detection backend.');
assert(isfield(s,'maxSynapseDensity'), ...
    'SILo params are missing maxSynapseDensity.');
assert(isempty(s.maxSynapseDensity), ...
    'maxSynapseDensity should remain empty for native SILo by default.');

fprintf('Checking summarize_LoCo parameter validation...\n');
% 0.01 is a validation sentinel only, NOT a recommended scientific setting.
locoTest = struct( ...
    'sourceDetectionMethod','summarize_loco', ...
    'maxSynapseDensity',0.01);

s2 = setParams('SILo', locoTest);
assert(strcmp(s2.sourceDetectionMethod,'summarize_loco'), ...
    'summarize_loco backend normalization failed.');
assert(s2.maxSynapseDensity == 0.01, ...
    'maxSynapseDensity was not preserved.');

fprintf('All GIAnT parameter integration checks passed.\n');
end
