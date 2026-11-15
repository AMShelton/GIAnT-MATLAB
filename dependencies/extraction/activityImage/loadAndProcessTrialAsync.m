function [meanIM, IMc, aData, peaks, discardFrames, status] = ...
    loadAndProcessTrialAsync(mocoDr, fn, numChannels, params)
%LOADANDPROCESSTRIALASYNC Load one registered trial and localize activity.
%
% status (6th output) reports per-trial problems instead of aborting the
% whole session: status.ok, status.reason ('' | 'too_many_discarded_frames' |
% 'localization_failed'), status.message, status.discardFrac. A trial with
% status.ok == false returns an all-NaN activity image and no peaks; SILo
% records the reason in trialQC and excludes the trial.
%
% The legacy helper returned the full registered activity movie as output 1,
% even though SILo discarded it. This RAM-optimized internal API returns only
% the compact products that SILo actually consumes.
%
% RAM-optimized GIAnT variant:
%   * alignment metadata are loaded without /slap2/varFacDS;
%   * varFacDS is passed to localizeSources_vIM as an on-disk HDF5 source;
%   * the full variance-factor movie is never materialized in this function.

    if endsWith(fn, '.h5')
        desc = h5info(fullfile(mocoDr, fn));
        IM = h5read(fullfile(mocoDr, fn), ['/', desc.Datasets.Name]);
    else
        IM = ScanImageTiffWrapper(fullfile(mocoDr, fn));
    end
    IM = reshape(IM, size(IM,1), size(IM,2), numChannels, []); % deinterleave

    % Keep mean images compact. Mean() preserves single when IM is single.
    meanIM = mean(IM, 4, 'omitnan');
    nanPx = mean(isnan(IM), [3 4]) > params.nanThresh;
    for cix = 1:size(meanIM,3)
        tmp = meanIM(:,:,cix);
        tmp(nanPx) = nan;
        meanIM(:,:,cix) = tmp;
    end

    % Retain only the activity channel before source localization. This
    % releases the multi-channel registered movie once MATLAB drops the old
    % array after assignment.
    IM = squeeze(IM(:,:,params.activityChannel,:));

    % Load lightweight alignment metadata. Do NOT use loadStructFromH5 here:
    % current alignment files may contain a multi-GB /slap2/varFacDS movie.
    fnStemEnd = strfind(fn, '_REGISTERED') - 1;
    alignmentPath = fullfile(mocoDr, ...
        [fn(1:fnStemEnd) '_ALIGNMENTDATA.h5']);
    aData = loadAlignmentDataLite(alignmentPath);
    aData.dsFac = 1; % SLAP2 data does not have downsampling per se
    params.dsFac = aData.dsFac;
    params.alignHz = aData.alignHz;
    nInitFrames = ceil(params.discardInitial_s * params.alignHz);

    % Discard motion frames.
    tmp = aData.recNegErr(:) - ...
        medfilt1(aData.recNegErr(:), round(4*params.alignHz));
    tmp = -tmp ./ min(-0.005, prctile(tmp,5));
    thresh = params.motionThresh;
    window = 2*ceil(0.025*params.alignHz)+1;
    discardFrames = imclose( ...
        imdilate(tmp>thresh, ones(window,1)) & (tmp>(thresh/2)), ...
        ones(window,1));
    discardFrames(1:min(nInitFrames, numel(discardFrames))) = true;
    IM(:,:,discardFrames) = nan;

    status = struct('ok', true, 'reason', '', 'message', '', ...
        'discardFrac', mean(discardFrames(:)));
    % A trial in which most frames are motion-censored cannot support the
    % variance model in localizeSources_vIM (it fails with 'Could not
    % estimate a finite positive variance intercept Vb' once valid pixels
    % have >40% NaN). Exclude it cleanly, with the reason recorded.
    maxDiscardFrac = 0.4;
    if isfield(params, 'maxDiscardFrac') && ~isempty(params.maxDiscardFrac)
        maxDiscardFrac = params.maxDiscardFrac;
    end
    if status.discardFrac > maxDiscardFrac
        status.ok = false;
        status.reason = 'too_many_discarded_frames';
        status.message = sprintf('%.0f%% of frames motion-censored (maxDiscardFrac %.2f)', ...
            100*status.discardFrac, maxDiscardFrac);
        warning('loadAndProcessTrialAsync:TooManyDiscardedFrames', '%s: %s; trial excluded', fn, status.message);
        IMc = nan(size(IM,1), size(IM,2), 'single');
        peaks = [];
        return
    end

    % Describe varFacDS lazily instead of loading H x W x T into RAM.
    vSource = [];
    if h5DatasetExists(alignmentPath, '/slap2/varFacDS')
        vSource = struct( ...
            'filename', alignmentPath, ...
            'dataset', '/slap2/varFacDS');
    end

    try
        [IMc, peaks] = localizeSources_vIM(IM, vSource, params);
    catch ME
        % Preserve the legacy one-time edge-artifact retry. If the retry also
        % fails, retain both errors so parallel-worker reports show the real
        % original failure rather than only the second exception.
        IM([1 end],:,:) = nan;
        IM(:,[1 end],:) = nan;
        try
            [IMc, peaks] = localizeSources_vIM(IM, vSource, params);
            warning('loadAndProcessTrialAsync:LocalizationRetry', ...
                'Localization succeeded after masking image edges. Initial error: %s', ...
                ME.message);
        catch ME2
            % Report, exclude this trial, and let the session continue; the
            % reason reaches experiment_summary.h5 via SILo's trialQC.
            status.ok = false;
            status.reason = 'localization_failed';
            status.message = sprintf('%s (retry after edge masking: %s)', ME.message, ME2.message);
            warning('loadAndProcessTrialAsync:LocalizationFailed', ...
                '%s: source localization failed; trial excluded. %s', fn, status.message);
            IMc = nan(size(IM,1), size(IM,2), 'single');
            peaks = [];
        end
    end
end


function tf = h5DatasetExists(filename, datasetPath)
tf = false;
try
    h5info(filename, datasetPath);
    tf = true;
catch
end
end
