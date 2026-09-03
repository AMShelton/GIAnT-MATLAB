function params = setParams(fnName, paramsIn, forceGUI)
%A shared parameter-setting function

switch fnName
    case 'SILo'
        params.isSLAP2 = false;          tooltips.isSLAP2 = 'Set true for SLAP2 data';
        params.includeIntegrationROIs = false; tooltips.includeIntegrationROIs = 'Use integration ROIs for trace extraction?';
        params.sigma_px = 1.33;          tooltips.sigma_px = 'Estimated radius of the PSF (gaussian sigma)';
        params.nmfIter = 2;              tooltips.nmfIter = 'number of iterations of NMF refinement';
        params.dXY = 3;                  tooltips.dXY = 'how large sources can be (radius), pixels';
        params.photonScale = [];              tooltips.photonScale = 'roughly the single-photon amplitude. Leave empty to use default/estimate from data.';
        % params.minBaseline = 1/10;              tooltips.minBaseline = 'minimum baseline for source extraction (normalized photon units)';
        params.lambda = 0.5;              tooltips.lambda = 'regularizer for source extraction';
        params.phi = 0.1;              tooltips.phi = 'parameter for how much to relax L1 during debiasing';
        params.denoiseWindow_s = 0.2;   tooltips.denoiseWindow_s= 'the timescale on which signals can be smoothed when denoising, seconds';
        params.baselineWindow_Glu_s = 4; tooltips.baselineWindow_Glu_s= 'timescale for calculating F0 in glutamate channel, seconds';
        params.baselineWindow_Ca_s = 4;  tooltips.baselineWindow_Ca_s= 'timescale for calculating F0 in calcium channel, seconds';
        params.activityChannel = 1;      tooltips.activityChannel = 'the channel of the original tiff image that contains the glutamate signal';
        params.tau_s = 0.03;             tooltips.tau_s = 'decay time constant of glutamate signal';
        params.tau2_s = 0.15;            tooltips.tau2_s = 'decay time constant of 2nd channel signal at synapses (usually spine calcium)';
        params.VIF = 1.38;                  tooltips.VIF = 'variance inflation factor for stdIM estimate';

        % Source-detection backend. Native SILo remains the default.
        params.sourceDetectionMethod = 'silo';
        tooltips.sourceDetectionMethod = 'Source detector: native SILo or summarize_LoCo-compatible source selection.';
        tooltips.choiceLists.sourceDetectionMethod = {'silo','summarize_loco'};
        params.maxSynapseDensity = [];
        tooltips.maxSynapseDensity = 'summarize_loco only: maximum candidate-source density as a fraction of valid non-soma pixels. Ignored by native SILo.';

        params.peakth = 10;             tooltips.peakth = 'peak identification threshold (actIM z-score)';
        params.minPeakDistance = 1;     tooltips.minPeakDistance = 'minimum Chebyshev distance between peaks (pixels); 1 = adjacent peaks allowed';
        params.nWorkers = 12;           tooltips.nWorkers = 'number of parallel workers';
        params.drawUserRois = true;     tooltips.drawUserRois = 'pop up a GUI to annotate user ROIs?';  
        params.motionThresh = 2.5;       tooltips.motionThresh = 'decrease this to be more stringent on motion correction when censoring frames';
        params.analyzeHz = 200;          tooltips.analyzeHz = 'frame rate used for analysis (SLAP2 only)';
        params.nanThresh = 0.33;         tooltips.nanThresh = 'Max fraction of samples that can be NaN for including a pixel in analysis';
        params.discardInitial_s = 0;     tooltips.discardInitial_s = 'time in seconds to remove from analysis at the start of each trial, to account for warmup';
        params.localizationTileSize = 96; tooltips.localizationTileSize = 'RAM optimization only: spatial tile size for activity localization. Larger is usually faster but uses more RAM per worker.';
        params.localizationTempDir = tempdir; tooltips.localizationTempDir = 'RAM optimization only: local temporary directory used to rechunk legacy varFacDS H5 datasets. Prefer a fast local SSD.';
        params.extractionWorkers = 8; tooltips.extractionWorkers = 'Performance only: number of thread workers used for high-resolution source/NMF subproblems.';
        params.highResBlockFrames = 600; tooltips.highResBlockFrames = 'Performance only: requested number of 200-Hz frames reconstructed per SLAP2 high-resolution input block.';
        params.highResBlockMemoryGB = 12; tooltips.highResBlockMemoryGB = 'Performance only: conservative RAM budget for one full-raster getImages block; highResBlockFrames is capped to fit.';
        params.selectedInterpBatchFrames = 64; tooltips.selectedInterpBatchFrames = 'Performance only: number of frames vectorized together during sparse motion interpolation.';
        params.reuseSlap2Reader = true; tooltips.reuseSlap2Reader = 'Performance only: reuse one Slap2DataFile/metadata object across pseudo-trials from the same DAT file.';
        params.savePerTrialSummary = true; tooltips.savePerTrialSummary = 'Save per_trial_summary.h5. Disable to avoid the very large full-FOV per-trial footprint file.';
        params.solverRobustFallback = true; tooltips.solverRobustFallback = 'Retry only the rare MATLAB trdog/quad1d trust-region numerical failure with a damped Hessian approximation.';
        params.solverRetryDamping = [1e-8 1e-6 1e-4]; tooltips.solverRetryDamping = 'Relative Hessian diagonal damping levels tried only after a trdog/quad1d failure.';
        params.solverRetryPCGIter = 3; tooltips.solverRetryPCGIter = 'Max PCG iterations used only for a trdog/quad1d solver retry.';
    case 'MultiRoiRegistration'
        params.alignHz = 80; tooltips.alignHz = 'Frequency for generating downsampled aligned tiffs';
        params.maxshift = 40; tooltips.maxshift = 'Maximum frame offset,in pixels';
        params.clipShift = 5; tooltips.clipShift = 'Maximum allowable shift per frame';
        params.alpha = 0.005; tooltips.alpha = 'exponential decay of template per frame';%exponential time constant for template
        params.nWorkers = 8; tooltips.nWorkers = 'number of process workers; 8 is the tested default for MultiROI registration on this workstation class';
        params.overwriteExisting = false; tooltips.overwriteExisting = 'Realign and overwrite any existing files?';
        params.refStackTemplate = false; tooltips.refStackTemplate = 'Use ref stack as template';
        params.isReVolt = false; tooltips.isReVolt = 'select true for recordings with simultaneous red 1P imaging';
        params.includeIntegrationROIs = false; tooltips.includeIntegrationROIs = 'Use integration ROIs for alignment and TIFF generation?';
        params.varFacChunkXY = 128; tooltips.varFacChunkXY = 'Performance only: spatial HDF5 chunk size for varFacDS. 128 avoids a SILo rechunk pass.';
        params.registrationBlockFrames = 128; tooltips.registrationBlockFrames = 'Performance only: requested number of 80-Hz frames reconstructed per Slap2DataReader getImages block.';
        params.registrationBlockMemoryGB = 4; tooltips.registrationBlockMemoryGB = 'Performance only: per-worker RAM budget for one batched registration read; registrationBlockFrames is capped automatically.';
        params.reuseSlap2Reader = true; tooltips.reuseSlap2Reader = 'Performance only: reuse a worker-local Slap2DataFile and parsed metadata across pseudo-trials from the same DAT.';
        params.useFastWeightedXcorr = true; tooltips.useFastWeightedXcorr = 'Use allocation-efficient weighted local correlation with the same correlation statistic and subpixel peak fit.';
        params.useMexWeightedXcorr = true; tooltips.useMexWeightedXcorr = 'Performance only: use the optional exact C++ MEX weighted-xcorr backend when a validated binary is available. Falls back automatically to MATLAB fast xcorr if unavailable or if any MEX call fails.';
        params.validateMexWeightedXcorr = true; tooltips.validateMexWeightedXcorr = 'Safety guardrail: numerically compare the MEX backend with the MATLAB fast implementation once per MATLAB process/worker before first use.';
        params.useAdaptiveWeightedXcorr = false; tooltips.useAdaptiveWeightedXcorr = 'Optional/experimental performance mode: search a smaller radius first in the main registration loop and expand to the full clipShift on boundary/audit cases. OFF by default to preserve exhaustive-search behavior.';
        params.adaptiveXcorrRadius = 2; tooltips.adaptiveXcorrRadius = 'Adaptive mode only: initial local search radius in pixels. Full clipShift is retained as fallback.';
        params.adaptiveXcorrAuditEvery = 100; tooltips.adaptiveXcorrAuditEvery = 'Adaptive mode only: every N main-loop frames, force a full-radius audit. Disagreement disables adaptive mode on that worker.';
        params.adaptiveXcorrMinCorrelation = -1; tooltips.adaptiveXcorrMinCorrelation = 'Adaptive mode only: expand to full search when the small-radius correlation is below this value. -1 effectively disables this trigger.';
        params.useFastInterpolation = true; tooltips.useFastInterpolation = 'Use translation-specialized bilinear interpolation; for two channels, coordinate/freshness lookup is shared.';
    case 'BandRegistration'
        params.alignHz = 80; tooltips.alignHz = 'Frequency for generating downsampled aligned tiffs';
        params.maxshiftXY = 25; tooltips.maxshift = 'Maximum frame offset,in pixels';
        params.maxshiftZ = 10; tooltips.maxshift = 'Maximum frame offset,in pixels';
        params.clipShift = 5; tooltips.clipShift = 'Maximum allowable shift per frame';
        params.motionMetric = {'''poisson''','''correlation'''}; tooltips.motionMetric = 'Metric for selecting best motion shift';
        params.robust = false; tooltips.robust = 'Use robust likelihood?';
        params.efficientTiffSave = false; tooltips.efficientTiffSave = 'Save Tiffs locally first then transfer?';
        params.tempFileDir = tempdir; tooltips.tempFileDir = 'Directory for temp files';
        % params.alpha = 0.005; tooltips.alpha = 'exponential decay of template per frame';%exponential time constant for template
        params.nWorkers = 16; tooltips.nWorkers = 'number of parallel workers';
        params.overwriteExisting = false; tooltips.overwriteExisting = 'Realign and overwrite any existing files?';
        params.integrationOnly = false; tooltips.integrationOnly = 'Align only on integration superpixels';
        params.saveTiffs = true; tooltips.saveTiffs = 'Save aligned tiff movies';
    case 'StripRegistration'
        params.maxshift = 50; tooltips.maxshift = 'Maximum frame offset,in pixels';
        params.clipShift = 10; tooltips.clipShift = 'Maximum allowable shift per frame';
        params.nWorkers = 4; tooltips.nWorkers = 'number of parallel workers';
        params.removeLines = 4; tooltips.removeLines = 'remove this many flyback lines from the top of each image';
        params.ds_time = 3; tooltips.ds_time = 'movies are downsampled (2^ds_time)x in time for alignment';
        params.frameRate = 0; tooltips.frameRate = 'imaging frame rate; if 0, calculated from metadata or set as default';
        params.saveTif = true; tooltips.saveTif = 'whether to save registered movie as .tif or .h5';
    otherwise
        error('Unknown function name passed to setParams.m')
end

if nargin>1 %if the user specified parameters, add user values and use defaults for remaining fields
    paramsIn = coerceLegacyParamNames(paramsIn);
    for field = fieldnames(paramsIn)'
        params.(field{1}) = paramsIn.(field{1});
    end
    params = normalizeParams(fnName, params);
    if nargin<3 || ~forceGUI
        return
    end
else
    params = normalizeParams(fnName, params);
end

% Get parameters from user. optionsGUI merges legacy saved presets into the
% current parameter schema, so fields added in newer versions keep defaults.
paramsIn = optionsGUI(params, tooltips, fnName);
params = coerceLegacyParamNames(paramsIn);
params = normalizeParams(fnName, params);

end

function params = coerceLegacyParamNames(params)
%COERCELEGACYPARAMNAMES Map renamed params fields to current names.
if ~isstruct(params) || isempty(params)
    return
end
if isfield(params, 'microscope')
    if ~isfield(params, 'isSLAP2')
        params.isSLAP2 = strcmpi(params.microscope, 'SLAP2');
    end
    params = rmfield(params, 'microscope');
end
if isfield(params, 'isSLAP2')
    params.isSLAP2 = logicalScalar(params.isSLAP2,'isSLAP2');
end
if isfield(params, 'nParallelWorkers')
    if ~isfield(params, 'nWorkers')
        params.nWorkers = params.nParallelWorkers;
    end
    params = rmfield(params, 'nParallelWorkers');
end
% Accept the early integration field name, if present in a saved preset.
if isfield(params, 'sourceDetectionBackend') && ~isfield(params, 'sourceDetectionMethod')
    params.sourceDetectionMethod = params.sourceDetectionBackend;
end
if isfield(params, 'sourceDetectionBackend')
    params = rmfield(params, 'sourceDetectionBackend');
end
% Drop legacy provenance fields (not algorithm inputs)
if isfield(params, 'operator')
    params = rmfield(params, 'operator');
end
end

function params = normalizeParams(fnName, params)
%NORMALIZEPARAMS Normalize/validate non-scientific runtime parameters.

if strcmp(fnName, 'MultiRoiRegistration')
    validateattributes(params.alignHz,{'numeric'},{'scalar','real','finite','positive'},mfilename,'alignHz');
    validateattributes(params.maxshift,{'numeric'},{'scalar','real','finite','nonnegative'},mfilename,'maxshift');
    validateattributes(params.clipShift,{'numeric'},{'scalar','real','finite','nonnegative'},mfilename,'clipShift');
    if params.maxshift ~= round(params.maxshift) || params.clipShift ~= round(params.clipShift)
        error('setParams:NonIntegerMotionSearch','maxshift and clipShift must be integer pixel counts.');
    end
    if params.clipShift > params.maxshift
        error('setParams:InvalidMotionSearch','clipShift (%g) cannot exceed maxshift (%g).',params.clipShift,params.maxshift);
    end
    validateattributes(params.alpha,{'numeric'},{'scalar','real','finite','>=',0,'<=',1},mfilename,'alpha');
    validateattributes(params.nWorkers,{'numeric'},{'scalar','real','finite','positive'},mfilename,'nWorkers');
    params.nWorkers = max(1,round(double(params.nWorkers)));
    params.overwriteExisting = logicalScalar(params.overwriteExisting,'overwriteExisting');
    params.refStackTemplate = logicalScalar(params.refStackTemplate,'refStackTemplate');
    params.isReVolt = logicalScalar(params.isReVolt,'isReVolt');
    params.includeIntegrationROIs = logicalScalar(params.includeIntegrationROIs,'includeIntegrationROIs');

    if ~isfield(params,'varFacChunkXY') || isempty(params.varFacChunkXY)
        params.varFacChunkXY = 128;
    end
    validateattributes(params.varFacChunkXY, {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, 'varFacChunkXY');
    params.varFacChunkXY = max(16,round(double(params.varFacChunkXY)));

    if ~isfield(params,'registrationBlockFrames') || isempty(params.registrationBlockFrames)
        params.registrationBlockFrames = 128;
    end
    validateattributes(params.registrationBlockFrames, {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, 'registrationBlockFrames');
    params.registrationBlockFrames = max(1,round(double(params.registrationBlockFrames)));

    if ~isfield(params,'registrationBlockMemoryGB') || isempty(params.registrationBlockMemoryGB)
        params.registrationBlockMemoryGB = 4;
    end
    validateattributes(params.registrationBlockMemoryGB, {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, 'registrationBlockMemoryGB');
    params.registrationBlockMemoryGB = double(params.registrationBlockMemoryGB);

    if ~isfield(params,'reuseSlap2Reader') || isempty(params.reuseSlap2Reader)
        params.reuseSlap2Reader = true;
    end
    params.reuseSlap2Reader = logicalScalar(params.reuseSlap2Reader,'reuseSlap2Reader');

    if ~isfield(params,'useFastWeightedXcorr') || isempty(params.useFastWeightedXcorr)
        params.useFastWeightedXcorr = true;
    end
    params.useFastWeightedXcorr = logicalScalar(params.useFastWeightedXcorr,'useFastWeightedXcorr');

    if ~isfield(params,'useMexWeightedXcorr') || isempty(params.useMexWeightedXcorr)
        params.useMexWeightedXcorr = true;
    end
    params.useMexWeightedXcorr = logicalScalar(params.useMexWeightedXcorr,'useMexWeightedXcorr');

    if ~isfield(params,'validateMexWeightedXcorr') || isempty(params.validateMexWeightedXcorr)
        params.validateMexWeightedXcorr = true;
    end
    params.validateMexWeightedXcorr = logicalScalar(params.validateMexWeightedXcorr,'validateMexWeightedXcorr');

    if ~isfield(params,'useAdaptiveWeightedXcorr') || isempty(params.useAdaptiveWeightedXcorr)
        params.useAdaptiveWeightedXcorr = false;
    end
    params.useAdaptiveWeightedXcorr = logicalScalar(params.useAdaptiveWeightedXcorr,'useAdaptiveWeightedXcorr');

    if ~isfield(params,'adaptiveXcorrRadius') || isempty(params.adaptiveXcorrRadius)
        params.adaptiveXcorrRadius = 2;
    end
    validateattributes(params.adaptiveXcorrRadius,{'numeric'}, ...
        {'scalar','real','finite','nonnegative'},mfilename,'adaptiveXcorrRadius');
    params.adaptiveXcorrRadius = min(round(double(params.adaptiveXcorrRadius)),params.clipShift);

    if ~isfield(params,'adaptiveXcorrAuditEvery') || isempty(params.adaptiveXcorrAuditEvery)
        params.adaptiveXcorrAuditEvery = 100;
    end
    validateattributes(params.adaptiveXcorrAuditEvery,{'numeric'}, ...
        {'scalar','real','finite','nonnegative'},mfilename,'adaptiveXcorrAuditEvery');
    params.adaptiveXcorrAuditEvery = round(double(params.adaptiveXcorrAuditEvery));

    if ~isfield(params,'adaptiveXcorrMinCorrelation') || isempty(params.adaptiveXcorrMinCorrelation)
        params.adaptiveXcorrMinCorrelation = -1;
    end
    validateattributes(params.adaptiveXcorrMinCorrelation,{'numeric'}, ...
        {'scalar','real','finite','>=',-1,'<=',1},mfilename,'adaptiveXcorrMinCorrelation');
    params.adaptiveXcorrMinCorrelation = double(params.adaptiveXcorrMinCorrelation);

    if params.useAdaptiveWeightedXcorr
        if params.clipShift < 2
            error('setParams:AdaptiveXcorrSearchTooSmall', ...
                'Adaptive weighted xcorr requires clipShift >= 2.');
        end
        if params.adaptiveXcorrRadius < 1 || params.adaptiveXcorrRadius >= params.clipShift
            error('setParams:InvalidAdaptiveXcorrRadius', ...
                'adaptiveXcorrRadius must be >=1 and strictly smaller than clipShift when adaptive xcorr is enabled.');
        end
        if params.adaptiveXcorrAuditEvery < 1
            error('setParams:AdaptiveXcorrAuditRequired', ...
                'adaptiveXcorrAuditEvery must be >=1 when adaptive xcorr is enabled.');
        end
    end

    if ~isfield(params,'useFastInterpolation') || isempty(params.useFastInterpolation)
        params.useFastInterpolation = true;
    end
    params.useFastInterpolation = logicalScalar(params.useFastInterpolation,'useFastInterpolation');
    return
end

if ~strcmp(fnName, 'SILo')
    return
end

% Validate scientific settings without changing their values. Catch malformed
% GUI/preset inputs before localization or high-resolution extraction runs.
params.isSLAP2 = logicalScalar(params.isSLAP2,'isSLAP2');
params.includeIntegrationROIs = logicalScalar(params.includeIntegrationROIs,'includeIntegrationROIs');
params.drawUserRois = logicalScalar(params.drawUserRois,'drawUserRois');

% Normalize and validate the selectable source-detection backend.
if ~isfield(params,'sourceDetectionMethod') || isempty(params.sourceDetectionMethod)
    params.sourceDetectionMethod = 'silo';
end
if isstring(params.sourceDetectionMethod)
    if ~isscalar(params.sourceDetectionMethod)
        error('setParams:InvalidSourceDetectionMethod', ...
            'sourceDetectionMethod must be a scalar string or character vector.');
    end
    params.sourceDetectionMethod = char(params.sourceDetectionMethod);
end
if ~ischar(params.sourceDetectionMethod)
    error('setParams:InvalidSourceDetectionMethod', ...
        'sourceDetectionMethod must be a scalar string or character vector.');
end
switch lower(strtrim(params.sourceDetectionMethod))
    case {'silo','native','default'}
        params.sourceDetectionMethod = 'silo';
    case {'summarize_loco','summarize-loco','summarizeloco','loco'}
        params.sourceDetectionMethod = 'summarize_loco';
    otherwise
        error('setParams:InvalidSourceDetectionMethod', ...
            'sourceDetectionMethod must be "silo" or "summarize_loco".');
end

if ~isfield(params,'maxSynapseDensity')
    params.maxSynapseDensity = [];
end
if strcmp(params.sourceDetectionMethod,'summarize_loco')
    validateattributes(params.maxSynapseDensity,{'numeric'}, ...
        {'scalar','real','finite','positive','<=',1},mfilename,'maxSynapseDensity');
elseif ~isempty(params.maxSynapseDensity)
    validateattributes(params.maxSynapseDensity,{'numeric'}, ...
        {'scalar','real','finite','positive','<=',1},mfilename,'maxSynapseDensity');
end

validateattributes(params.sigma_px,{'numeric'},{'scalar','real','finite','positive'},mfilename,'sigma_px');
validateattributes(params.nmfIter,{'numeric'},{'scalar','real','finite','positive'},mfilename,'nmfIter');
if params.nmfIter ~= round(params.nmfIter)
    error('setParams:InvalidNmfIter','nmfIter must be a positive integer.');
end
validateattributes(params.dXY,{'numeric'},{'scalar','real','finite','positive'},mfilename,'dXY');
if ~isempty(params.photonScale)
    validateattributes(params.photonScale,{'numeric'},{'scalar','real','finite','positive'},mfilename,'photonScale');
end
validateattributes(params.lambda,{'numeric'},{'scalar','real','finite','nonnegative'},mfilename,'lambda');
validateattributes(params.phi,{'numeric'},{'scalar','real','finite','nonnegative'},mfilename,'phi');
validateattributes(params.denoiseWindow_s,{'numeric'},{'scalar','real','finite','positive'},mfilename,'denoiseWindow_s');
validateattributes(params.baselineWindow_Glu_s,{'numeric'},{'scalar','real','finite','positive'},mfilename,'baselineWindow_Glu_s');
validateattributes(params.baselineWindow_Ca_s,{'numeric'},{'scalar','real','finite','positive'},mfilename,'baselineWindow_Ca_s');
validateattributes(params.activityChannel,{'numeric'},{'scalar','real','finite','positive'},mfilename,'activityChannel');
if params.activityChannel ~= round(params.activityChannel)
    error('setParams:InvalidActivityChannel','activityChannel must be a positive integer.');
end
validateattributes(params.tau_s,{'numeric'},{'scalar','real','finite','positive'},mfilename,'tau_s');
validateattributes(params.tau2_s,{'numeric'},{'scalar','real','finite','positive'},mfilename,'tau2_s');
validateattributes(params.VIF,{'numeric'},{'scalar','real','finite','positive'},mfilename,'VIF');
validateattributes(params.peakth,{'numeric'},{'scalar','real','finite','nonnegative'},mfilename,'peakth');
validateattributes(params.minPeakDistance,{'numeric'},{'scalar','real','finite','positive'},mfilename,'minPeakDistance');
validateattributes(params.nWorkers,{'numeric'},{'scalar','real','finite','positive'},mfilename,'nWorkers');
params.nWorkers = max(1,round(double(params.nWorkers)));
validateattributes(params.motionThresh,{'numeric'},{'scalar','real','finite','nonnegative'},mfilename,'motionThresh');
validateattributes(params.nanThresh,{'numeric'},{'scalar','real','finite','>',0,'<=',1},mfilename,'nanThresh');
validateattributes(params.discardInitial_s,{'numeric'},{'scalar','real','finite','nonnegative'},mfilename,'discardInitial_s');
if params.isSLAP2
    validateattributes(params.analyzeHz,{'numeric'},{'scalar','real','finite','positive'},mfilename,'analyzeHz');
end

% Performance-only RAM optimization settings. These defaults make old
% parameter structures/presets forward-compatible with optimized SILo.
if ~isfield(params, 'localizationTileSize') || isempty(params.localizationTileSize)
    params.localizationTileSize = 96;
end
validateattributes(params.localizationTileSize, {'numeric'}, ...
    {'scalar','real','finite','positive'}, mfilename, 'localizationTileSize');
params.localizationTileSize = round(double(params.localizationTileSize));
if params.localizationTileSize < 16
    error('setParams:InvalidLocalizationTileSize', ...
        'localizationTileSize must be at least 16 pixels.');
end

if ~isfield(params, 'localizationTempDir') || isempty(params.localizationTempDir)
    params.localizationTempDir = tempdir;
end
if isstring(params.localizationTempDir)
    if ~isscalar(params.localizationTempDir)
        error('setParams:InvalidLocalizationTempDir', ...
            'localizationTempDir must be a scalar string or character vector.');
    end
    params.localizationTempDir = char(params.localizationTempDir);
end
if ~ischar(params.localizationTempDir)
    error('setParams:InvalidLocalizationTempDir', ...
        'localizationTempDir must be a character vector or scalar string.');
end

if ~isfolder(params.localizationTempDir)
    [ok, msg] = mkdir(params.localizationTempDir);
    if ~ok
        error('setParams:LocalizationTempDirUnavailable', ...
            'Could not create localizationTempDir "%s": %s', ...
            params.localizationTempDir, msg);
    end
end

if ~isfield(params, 'extractionWorkers') || isempty(params.extractionWorkers)
    params.extractionWorkers = min(8, params.nWorkers);
end
validateattributes(params.extractionWorkers, {'numeric'}, ...
    {'scalar','real','finite','positive'}, mfilename, 'extractionWorkers');
params.extractionWorkers = max(1, round(double(params.extractionWorkers)));

if ~isfield(params, 'highResBlockFrames') || isempty(params.highResBlockFrames)
    params.highResBlockFrames = 600;
end
validateattributes(params.highResBlockFrames, {'numeric'}, ...
    {'scalar','real','finite','positive'}, mfilename, 'highResBlockFrames');
params.highResBlockFrames = max(1, round(double(params.highResBlockFrames)));

if ~isfield(params, 'highResBlockMemoryGB') || isempty(params.highResBlockMemoryGB)
    params.highResBlockMemoryGB = 12;
end
validateattributes(params.highResBlockMemoryGB, {'numeric'}, ...
    {'scalar','real','finite','positive'}, mfilename, 'highResBlockMemoryGB');
params.highResBlockMemoryGB = double(params.highResBlockMemoryGB);

if ~isfield(params, 'selectedInterpBatchFrames') || isempty(params.selectedInterpBatchFrames)
    params.selectedInterpBatchFrames = 64;
end
validateattributes(params.selectedInterpBatchFrames, {'numeric'}, ...
    {'scalar','real','finite','positive'}, mfilename, 'selectedInterpBatchFrames');
params.selectedInterpBatchFrames = max(1,round(double(params.selectedInterpBatchFrames)));

if ~isfield(params, 'reuseSlap2Reader') || isempty(params.reuseSlap2Reader)
    params.reuseSlap2Reader = true;
end
params.reuseSlap2Reader = logicalScalar(params.reuseSlap2Reader,'reuseSlap2Reader');

if ~isfield(params, 'savePerTrialSummary') || isempty(params.savePerTrialSummary)
    params.savePerTrialSummary = true;
end
params.savePerTrialSummary = logicalScalar(params.savePerTrialSummary,'savePerTrialSummary');

if ~isfield(params, 'solverRobustFallback') || isempty(params.solverRobustFallback)
    params.solverRobustFallback = true;
end
params.solverRobustFallback = logicalScalar(params.solverRobustFallback,'solverRobustFallback');

if ~isfield(params, 'solverRetryDamping') || isempty(params.solverRetryDamping)
    params.solverRetryDamping = [1e-8 1e-6 1e-4];
end
validateattributes(params.solverRetryDamping, {'numeric'}, ...
    {'vector','real','finite','positive'}, mfilename, 'solverRetryDamping');
params.solverRetryDamping = double(params.solverRetryDamping(:).');

if ~isfield(params, 'solverRetryPCGIter') || isempty(params.solverRetryPCGIter)
    params.solverRetryPCGIter = 3;
end
validateattributes(params.solverRetryPCGIter, {'numeric'}, ...
    {'scalar','real','finite','positive'}, mfilename, 'solverRetryPCGIter');
params.solverRetryPCGIter = max(1,round(double(params.solverRetryPCGIter)));
end

function tf = logicalScalar(value,name)
%LOGICALSCALAR Accept logical scalars and numeric 0/1 from legacy MAT presets.
if islogical(value) && isscalar(value)
    tf = value;
    return
end
if isnumeric(value) && isscalar(value) && isfinite(value) && (value==0 || value==1)
    tf = logical(value);
    return
end
error('setParams:InvalidLogicalParameter', ...
    '%s must be a scalar logical or numeric 0/1.',name);
end
