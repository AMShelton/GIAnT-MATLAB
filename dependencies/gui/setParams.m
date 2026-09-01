function params = setParams(fnName, paramsIn, forceGUI)
%A shared parameter-setting function
switch fnName
    case 'SILo'
        params.isSLAP2 = false;          tooltips.isSLAP2 = 'Set true for SLAP2 data';
        params.includeIntegrationROIs = false; tooltips.includeIntegrationROIs = 'Use integration ROIs for trace extraction?';
        params.sigma_px = 1.33;          tooltips.sigma_px = 'Estimated radius of the PSF (gaussian sigma)';
        params.nmfIter = 2;              tooltips.nmfIter = 'number of iterations of NMF refinement';
        params.dXY = 3;                  tooltips.dXY = 'how large sources can be (radius), pixels';
        params.photonScale = [];         tooltips.photonScale = 'roughly the single-photon amplitude. Leave empty to use default/estimate from data.';
        % params.minBaseline = 1/10;      tooltips.minBaseline = 'minimum baseline for source extraction (normalized photon units)';
        params.lambda = 0.5;             tooltips.lambda = 'regularizer for source extraction';
        params.phi = 0.1;                tooltips.phi = 'parameter for how much to relax L1 during debiasing';
        params.denoiseWindow_s = 0.2;    tooltips.denoiseWindow_s = 'the timescale on which signals can be smoothed when denoising, seconds';
        params.baselineWindow_Glu_s = 4; tooltips.baselineWindow_Glu_s = 'timescale for calculating F0 in glutamate channel, seconds';
        params.baselineWindow_Ca_s = 4;  tooltips.baselineWindow_Ca_s = 'timescale for calculating F0 in calcium channel, seconds';
        params.activityChannel = 1;      tooltips.activityChannel = 'the channel of the original tiff image that contains the glutamate signal';
        params.tau_s = 0.03;             tooltips.tau_s = 'decay time constant of glutamate signal';
        params.tau2_s = 0.15;            tooltips.tau2_s = 'decay time constant of 2nd channel signal at synapses (usually spine calcium)';
        params.VIF = 1.38;               tooltips.VIF = 'variance inflation factor for stdIM estimate';

        % Source detection backend.
        % Keep a scalar char default so non-GUI/programmatic SILo calls behave
        % exactly like the historical implementation unless explicitly changed.
        params.sourceDetectionMethod = 'silo';
        tooltips.sourceDetectionMethod = [ ...
            'Source detection backend. "silo" uses native GIAnT/SILo peak ' ...
            'detection; "summarize_loco" uses the legacy summarize_LoCo-compatible detector.'];
        tooltips.choiceLists.sourceDetectionMethod = {'silo', 'summarize_loco'};

        % summarize_LoCo-specific density cap. The authoritative historical
        % default is not defined in the supplied summarize_LoCo.m itself, so do
        % not silently invent one. It is required only when summarize_loco is used.
        params.maxSynapseDensity = [];
        tooltips.maxSynapseDensity = [ ...
            'summarize_LoCo only: maximum source density (fraction of valid, ' ...
            'non-soma image pixels). Set this to the value used by the legacy ' ...
            'summarize_LoCo configuration. Ignored by native SILo.'];

        params.peakth = 10;              tooltips.peakth = 'peak identification threshold (actIM z-score; native SILo only)';
        params.minPeakDistance = 1;      tooltips.minPeakDistance = 'minimum Chebyshev distance between peaks (pixels); 1 = adjacent peaks allowed; native SILo only';
        params.nWorkers = 12;            tooltips.nWorkers = 'number of parallel workers';
        params.drawUserRois = true;      tooltips.drawUserRois = 'pop up a GUI to annotate user ROIs?';
        params.motionThresh = 2.5;       tooltips.motionThresh = 'decrease this to be more stringent on motion correction when censoring frames';
        params.analyzeHz = 200;          tooltips.analyzeHz = 'frame rate used for analysis (SLAP2 only)';
        params.nanThresh = 0.33;         tooltips.nanThresh = 'Max fraction of samples that can be NaN for including a pixel in analysis';
        params.discardInitial_s = 0;     tooltips.discardInitial_s = 'time in seconds to remove from analysis at the start of each trial, to account for warmup';

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

if nargin>1 %if the user specified parameters, add in the user parameters, use defaults for remaining, NO GUI
    paramsIn = coerceLegacyParamNames(paramsIn);
    for field = fieldnames(paramsIn)'
        params.(field{1}) = paramsIn.(field{1});
    end
    params = normalizeAndValidateParams(params, fnName);

    if nargin<3 || ~forceGUI
        return
    end
end

%get parameters from user
paramsIn = optionsGUI(params, tooltips, fnName);
params = coerceLegacyParamNames(paramsIn);
params = normalizeAndValidateParams(params, fnName);

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

% Accept early names used during summarize_LoCo/SILo integration.
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

function params = normalizeAndValidateParams(params, fnName)
%NORMALIZEANDVALIDATEPARAMS Normalize first-class SILo backend parameters.
if ~strcmp(fnName, 'SILo')
    return
end

if ~isfield(params, 'sourceDetectionMethod') || isempty(params.sourceDetectionMethod)
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

method = lower(strtrim(params.sourceDetectionMethod));
switch method
    case {'silo', 'default', 'native'}
        params.sourceDetectionMethod = 'silo';
    case {'summarize_loco', 'summarize-loco', 'summarizeloco', 'loco'}
        params.sourceDetectionMethod = 'summarize_loco';
    otherwise
        error('setParams:InvalidSourceDetectionMethod', ...
            ['Unknown sourceDetectionMethod "%s". Valid choices are ' ...
             '"silo" and "summarize_loco".'], params.sourceDetectionMethod);
end

if ~isfield(params, 'maxSynapseDensity')
    params.maxSynapseDensity = [];
end

if strcmp(params.sourceDetectionMethod, 'summarize_loco')
    density = params.maxSynapseDensity;
    if isempty(density) || ~isnumeric(density) || ~isscalar(density) || ...
            ~isfinite(density) || density <= 0 || density > 1
        error('setParams:MissingMaxSynapseDensity', ...
            ['summarize_loco requires maxSynapseDensity to be a finite scalar ' ...
             'in (0, 1]. Set it to the value used by the legacy summarize_LoCo ' ...
             'configuration before running the benchmark.']);
    end
elseif ~isempty(params.maxSynapseDensity)
    density = params.maxSynapseDensity;
    if ~isnumeric(density) || ~isscalar(density) || ~isfinite(density) || ...
            density <= 0 || density > 1
        error('setParams:InvalidMaxSynapseDensity', ...
            'maxSynapseDensity, when supplied, must be a finite scalar in (0, 1].');
    end
end
end
