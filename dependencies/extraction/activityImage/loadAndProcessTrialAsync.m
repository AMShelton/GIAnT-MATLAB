function [meanIM, IMc, aData, peaks, discardFrames] = ...
    loadAndProcessTrialAsync(mocoDr, fn, numChannels, params)
%LOADANDPROCESSTRIALASYNC Load one registered trial and localize activity.
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
            ME2 = addCause(ME2,ME);
            rethrow(ME2);
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
