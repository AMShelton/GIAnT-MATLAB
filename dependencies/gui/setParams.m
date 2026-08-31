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
    case 'MultiRoiRegistration'
        params.alignHz = 80; tooltips.alignHz = 'Frequency for generating downsampled aligned tiffs';
        params.maxshift = 40; tooltips.maxshift = 'Maximum frame offset,in pixels';
        params.clipShift = 5; tooltips.clipShift = 'Maximum allowable shift per frame';
        params.alpha = 0.005; tooltips.alpha = 'exponential decay of template per frame';%exponential time constant for template
        params.nWorkers = 16; tooltips.nWorkers = 'number of parallel workers';
        params.overwriteExisting = false; tooltips.overwriteExisting = 'Realign and overwrite any existing files?';
        params.refStackTemplate = false; tooltips.refStackTemplate = 'Use ref stack as template';
        params.isReVolt = false; tooltips.isReVolt = 'select true for recordings with simultaneous red 1P imaging';
        params.includeIntegrationROIs = false; tooltips.includeIntegrationROIs = 'Use integration ROIs for alignment and TIFF generation?';
        params.varFacChunkXY = 128; tooltips.varFacChunkXY = 'Performance only: spatial HDF5 chunk size for varFacDS. 128 avoids a SILo rechunk pass.';
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
    params.isSLAP2 = logical(params.isSLAP2);
end
if isfield(params, 'nParallelWorkers')
    if ~isfield(params, 'nWorkers')
        params.nWorkers = params.nParallelWorkers;
    end
    params = rmfield(params, 'nParallelWorkers');
end
% Drop legacy provenance fields (not algorithm inputs)
if isfield(params, 'operator')
    params = rmfield(params, 'operator');
end
end

function params = normalizeParams(fnName, params)
%NORMALIZEPARAMS Normalize/validate non-scientific runtime parameters.

if strcmp(fnName, 'MultiRoiRegistration')
    if ~isfield(params,'varFacChunkXY') || isempty(params.varFacChunkXY)
        params.varFacChunkXY = 128;
    end
    validateattributes(params.varFacChunkXY, {'numeric'}, ...
        {'scalar','real','finite','positive'}, mfilename, 'varFacChunkXY');
    params.varFacChunkXY = max(16,round(double(params.varFacChunkXY)));
    return
end

if ~strcmp(fnName, 'SILo')
    return
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
params.reuseSlap2Reader = logical(params.reuseSlap2Reader);

if ~isfield(params, 'savePerTrialSummary') || isempty(params.savePerTrialSummary)
    params.savePerTrialSummary = true;
end
params.savePerTrialSummary = logical(params.savePerTrialSummary);
end

