function report = auditGIAnTInstall(giantRoot)
%AUDITGIANTINSTALL Check that the active GIAnT checkout is the reconciled optimized revision.
%
%   report = auditGIAnTInstall()
%   report = auditGIAnTInstall(giantRoot)

if nargin < 1 || isempty(giantRoot)
    p = which('processSLAP2');
    if isempty(p)
        error('GIAnT:NotOnPath','processSLAP2 is not on the MATLAB path.');
    end
    giantRoot = fileparts(p);
end
giantRoot = char(giantRoot);

requiredFunctions = {
    'processSLAP2',                    'processSLAP2.m'
    'SILo',                            fullfile('source_extraction','SILo.m')
    'extractTrial',                    fullfile('dependencies','extraction','extractTrial.m')
    'processAllTrials_Async',          fullfile('dependencies','extraction','processAllTrials_Async.m')
    'getCachedSlap2Resources',         fullfile('dependencies','extraction','getCachedSlap2Resources.m')
    'getActImPeaks',                   fullfile('dependencies','extraction','activityImage','getActImPeaks.m')
    'interpFramesSelected',            fullfile('dependencies','alignment','interpFramesSelected.m')
    'interpFramesSelectedBatch',       fullfile('dependencies','alignment','interpFramesSelectedBatch.m')
    'interpFrameTranslationChannels',  fullfile('dependencies','alignment','interpFrameTranslationChannels.m')
    'xcorr2_nans_weighted_fast',       fullfile('dependencies','alignment','xcorr2_nans_weighted_fast.m')
    'localizeSources_vIM',              fullfile('dependencies','extraction','activityImage','localizeSources_vIM.m')
    'setParamsExtractTrial',            fullfile('dependencies','extraction','setParamsExtractTrial.m')
    };

n = size(requiredFunctions,1);
Function = strings(n,1);
ExpectedFile = strings(n,1);
Exists = false(n,1);
OnPath = false(n,1);
FromThisCheckout = false(n,1);
ResolvedPath = strings(n,1);

rootNorm = lower(strrep(char(java.io.File(giantRoot).getCanonicalPath()),'\','/'));

for k = 1:n
    Function(k) = string(requiredFunctions{k,1});
    expected = fullfile(giantRoot,requiredFunctions{k,2});
    ExpectedFile(k) = string(expected);
    Exists(k) = isfile(expected);

    resolved = which(requiredFunctions{k,1});
    if ~isempty(resolved)
        OnPath(k) = true;
        ResolvedPath(k) = string(resolved);
        resolvedNorm = lower(strrep(char(java.io.File(resolved).getCanonicalPath()),'\','/'));
        FromThisCheckout(k) = startsWith(resolvedNorm,[rootNorm '/']) || strcmp(resolvedNorm,rootNorm);
    end
end

report = table(Function,Exists,OnPath,FromThisCheckout,ExpectedFile,ResolvedPath);
disp(report);

markerChecks = {
    fullfile('buildTrialTableSLAP2.m'), 'dynamic_data'
    fullfile('motion_correction','MultiRoiRegistration.m'), 'registrationBlockFrames'
    fullfile('motion_correction','MultiRoiRegistration.m'), 'xcorr2_nans_weighted_fast'
    fullfile('dependencies','gui','setParams.m'), 'solverRobustFallback'
    fullfile('dependencies','gui','optionsGUI.m'), 'coercePresetValue'
    fullfile('dependencies','extraction','extractTrial.m'), 'fminconTrustRegionRobust'
    fullfile('dependencies','extraction','processAllTrials_Async.m'), 'interpFramesSelectedBatch'
    fullfile('dependencies','extraction','processAllTrials_Async.m'), 'GIAnT:NaNFillFailed'
    fullfile('motion_correction','MultiRoiRegistration.m'), 'lastReaderError'
    fullfile('source_extraction','SILo.m'), 'SILo:NoValidAlignedTrials'
    fullfile('dependencies','extraction','extractTrial.m'), 'extractTrial:InvalidPhotonScale'
    };

fprintf('\nRevision-marker checks:\n');
markerOK = true;
for k = 1:size(markerChecks,1)
    fn = fullfile(giantRoot,markerChecks{k,1});
    ok = isfile(fn) && contains(fileread(fn),markerChecks{k,2});
    if ok
        status = 'OK';
    else
        status = 'MISSING';
    end
    fprintf('  [%s] %s :: %s\n',status,markerChecks{k,1},markerChecks{k,2});
    markerOK = markerOK && ok;
end

readerHelper = which('slap2.util.getCachedDataFile');
if isempty(readerHelper)
    fprintf(['\nINFO: slap2.util.getCachedDataFile was not found. GIAnT has an ' ...
        'internal reader-cache fallback, so this is not fatal.\n']);
else
    fprintf('\nSlap2DataReader cache helper: %s\n',readerHelper);
end

if any(~Exists) || any(~OnPath) || any(~FromThisCheckout) || ~markerOK
    warning('GIAnT:AuditFailed', ...
        ['GIAnT audit found missing, stale, or shadowed optimized files. ' ...
         'Reconcile this checkout before processing.']);
else
    fprintf('\nGIAnT optimized checkout audit PASSED.\n');
end
end
