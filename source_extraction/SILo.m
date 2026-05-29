function params = SILo(dr_or_pathToTrialTable, paramsIn)
%PARAMETER SETTING
if nargin>1
    if ischar(paramsIn)  % Parse JSON String to Structure
        paramsIn = jsondecode(paramsIn);
    end
    params = setParams('SILo', paramsIn);
else
    params = setParams('SILo');
end
% Fixed values; user/GUI/JSON cannot override these in SILo
params.poissBasedStdIM = 1;
params.peakFuncOpt = 2;
params.actImHeteroscedasticNoise = 0;
params.peakBufferSize = 0;
params.dimStdMethod = false;
params.minBaseline = 0.01;
if ~nargin
    [trialTablefn, dr] =  uigetfile('*.h5', 'Select a trial_table file', '*trial_table*.h5' );
else
    %parse dr
    %_or_pathToTrialTable
    if exist(dr_or_pathToTrialTable, 'dir')
        dr = dr_or_pathToTrialTable;
        trialTablefn = 'trial_table.h5';
    else
        [dr trialTablefn ext] = fileparts(dr_or_pathToTrialTable);
        trialTablefn = [trialTablefn ext];
    end
end

params.startTime = char(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ss.SSSZZZZZ'));

%confirm that all files exist (also populates source_extraction.fn_raw)
[trialTable, keepTrials] = verifyFiles(trialTablefn, dr);
mocodr = fullfile(trialTable.savedr, 'motion_correction');
% for dmdKey = fieldnames(trialTable.slap2_info.ref_stack)'
%     trialTable.slap2_info.ref_stack.(dmdKey{1}).IM = []; %this uses a lot of memory and we won't need it
% end
nDMDs = size(trialTable.filename,1); %the trial table has size #DMDs x # trials; Bergamo is treated as '1 DMD'
nTrials = size(trialTable.filename,2);

%parameters that depend only on the microscope, hidden from GUI
switch params.microscope
    case 'bergamo'
        params.analyzeHz = nan;
end

disp(['## SUMMARIZING' newline 'Folder:'])
disp(dr)

savedr = fullfile(trialTable.savedr, 'source_extraction');

if ~exist(savedr, 'dir')
    mkdir(savedr);
end

%call up a GUI for the user to define Soma ROI and regions to exclude
if params.drawUserRois
    annotationsDr = fullfile(trialTable.savedr, 'annotations');
    if ~exist(annotationsDr, 'dir')
        mkdir(annotationsDr);
    end
    fnAnnH5 = fullfile(annotationsDr, 'annotations.h5');
    if exist(fnAnnH5, 'file')
        ROIs = loadAnnotationsH5(fnAnnH5);
    else
        drawnDMDs = false(1, nDMDs);
        for DMDix = 1:nDMDs
            firstValidTrial = find(keepTrials(DMDix,:),1,"first");
            if isempty(firstValidTrial)
                warning('SILo:NoValidTrials', ...
                    'Skipping ROI drawing for imaging path %d: no trials passed file verification.', DMDix);
                ROIs(DMDix).dr = mocodr;
                ROIs(DMDix).fn = '';
                ROIs(DMDix).roiData = [];
                continue
            end
            %load image data (prefer meanIM from alignment H5 of same trial; matches mean(IM,[3 4]) after H,W,C,T reshape)
            [~, fn, ext] = fileparts(trialTable.motion_correction.fn_reg_ds{DMDix,firstValidTrial});
            adataFn = trialTable.motion_correction.fn_adata{DMDix, firstValidTrial};
            aDataAnnot = loadStructFromH5(fullfile(mocodr, adataFn));
            if isfield(aDataAnnot, 'meanIM') && ~isempty(aDataAnnot.meanIM)
                IM = squeeze(mean(aDataAnnot.meanIM, 1, 'omitnan')); % numChannels x H x W -> H x W
            else
                [IMtif, ~] = ScanImageTiffWrapper(fullfile(mocodr, [fn ext]));
                IM = squeeze(mean(IMtif, [3 4], 'omitnan'));
            end
            hROIs(DMDix) = drawROIs(sqrt(max(0,IM)), savedr, fn);
            ROIs(DMDix).dr = mocodr;
            ROIs(DMDix).fn = fn;
            drawnDMDs(DMDix) = true;
        end
        for DMDix = find(drawnDMDs)
            waitfor(hROIs(DMDix).hF);
            ROIs(DMDix).roiData = hROIs(DMDix).roiData;
        end
        saveAnnotationsH5(fnAnnH5, ROIs); clear hROIs;
    end
else
    ROIs = [];
end

%PROCESS DATA
for DMDix = nDMDs:-1:1
    firstValidTrial = find(keepTrials(DMDix,:),1,"first");
    if isempty(firstValidTrial)
        warning('SILo:NoValidTrials', ...
            'Skipping imaging path %d: no trials passed file verification.', DMDix);
        exptSummary.Z(DMDix) = nan;
        exptSummary.meanIM{DMDix} = [];
        exptSummary.actIM{DMDix} = [];
        exptSummary.selPix{DMDix} = [];
        exptSummary.sources{DMDix} = struct('R', [], 'C', [], 'V', []);
        exptSummary.userROIs{DMDix} = [];
        exptSummary.peaks{DMDix} = cell(1, nTrials);
        exptSummary.perTrialMeanIMs{DMDix} = [];
        exptSummary.perTrialMeanIMsAligned{DMDix} = [];
        exptSummary.perTrialActIms{DMDix} = [];
        exptSummary.perTrialActIMsAligned{DMDix} = [];
        exptSummary.perTrialAlignmentOffsets{DMDix} = [];
        continue
    end

    %load some metadata
    fn = trialTable.motion_correction.fn_adata{DMDix,firstValidTrial};
    aData = loadStructFromH5(fullfile(mocodr, fn));
    numChannels = aData.numChannels;
    params.numChannels = numChannels;
    params.alignHz = aData.alignHz;
    if ~strcmpi(params.microscope, 'SLAP2')
        params.analyzeHz = 1/aData.frametime; %analyze conventional recordings at the acquisitoin framerate
    end
    if isfield(aData, 'slap2') && isfield(aData.slap2, 'Z_depths')
        exptSummary.Z(DMDix) = aData.slap2.Z_depths;
    else
        exptSummary.Z(DMDix) = nan;
        warning('Alignment data missing Z_depths, likely out of date!!')
    end
    clear aData

    %set up parallelization
    if params.nParallelWorkers>1
        p = gcp('nocreate');
        if isempty(p)
            poolsize = 0;
        else
            poolsize = p.NumWorkers;
        end
        dd = dir(fullfile(mocodr, trialTable.motion_correction.fn_reg_ds{DMDix, firstValidTrial}));
        try
            fileSize = dd.bytes;
        catch
            error(['Error loading registered tiff:' trialTable.motion_correction.fn_reg_ds{DMDix, firstValidTrial} '\n' 'Are paths in your trial table valid?']);
        end
        if ispc
            userMemInfo = memory;
            memAvailable = userMemInfo.MemAvailableAllArrays;
        else
            [~, result] = unix('grep MemAvailable /proc/meminfo | awk ''{print $2}''');
            memAvailable = str2double(result) * 1024;  % Convert KB to bytes
        end
        maxWorkers = max(1,min(size(trialTable.filename,2), floor(0.13*memAvailable/fileSize)));
        nWorkers = min(params.nParallelWorkers, maxWorkers);
        
        if poolsize~=nWorkers ||  ~strcmpi(class(p), 'parallel.ProcessPool')
            delete(gcp('nocreate'));
            parpool('processes',nWorkers); %limit the number of workers to avoid running out of RAM 
        end
    else
        delete(gcp('nocreate'));
    end

    %Perform Localizations
    disp('Loading data and performing localizations...')
    mIM = cell(1, nTrials); aIM = cell(1,nTrials); alignData = cell(1, nTrials); peaks = cell(1, nTrials); discardFrames = cell(1,nTrials); %rawIMs = cell(1,nTrials)
    fns = trialTable.motion_correction.fn_reg_ds(DMDix, :);
    parfor trialIx = 1:nTrials
        if keepTrials(DMDix,trialIx)
            [~, mIM{trialIx}, aIM{trialIx}, alignData{trialIx}, peaks{trialIx}, discardFrames{trialIx}]= loadAndProcessTrialAsync(mocodr, fns{trialIx}, numChannels, params); %rawIMs{trialIx}
        end
    end
    %Assemble same-sized mean images from different-sized trial means
    szm1 = max(cellfun(@(x)size(x,1),mIM)); szm2 = max(cellfun(@(x)size(x,2), aIM));
    meanIM = nan(szm1,szm2,numChannels, nTrials); activIM = nan(szm1,szm2,1, nTrials);
    for trialIx = 1:nTrials
        tmp =  mIM{trialIx};
        meanIM(1:size(tmp,1),1:size(tmp,2),:,trialIx) = tmp;
        tmp =  aIM{trialIx};
        activIM(1:size(tmp,1),1:size(tmp,2),:,trialIx) = tmp;
    end
    params.sz = size(meanIM, [1 2]);

    %Make template
    disp('Making template for aligning across trials...')
    maxshift = 5;
    M = squeeze(sum(meanIM, 3));
    samples = find(keepTrials(DMDix,:)); samples = samples(unique(round(linspace(1,length(samples),20))));
    template = makeTemplateMultiRoi(M(:,:,samples), maxshift);

    %align all mean images to template
    disp('Aligning across trials...')
    meanAligned = [];
    actAligned = nan(size(meanIM,1), size(meanIM,2),1,nTrials);
    corrCoeff = nan(1,nTrials);
    motOutput = nan(2,nTrials);
    Mpad = nan([size(template) size(M,3)]);
    Mpad(maxshift+(1:size(M,1)), maxshift+(1:size(M,2)),:) = M;
    %clear M

    fillval = min(template(:),[], 'omitnan')-1;
    tFFT = fft2(max(template, fillval));
    for trialIx = nTrials:-1:1
        if ~keepTrials(DMDix,trialIx) || all(isnan(activIM(:,:,1,trialIx)), 'all')
            disp(['skipping trial, dmd:' int2str(trialIx) ' ' int2str(DMDix)])
            continue %skip
        end
        disp(['trial: ' int2str(trialIx)])
        
        output1 = dftregistration_clipped(tFFT, fft2(max(Mpad(:,:,trialIx), fillval)),1,80);
        mot1 = [-output1(3) -output1(4)]; %xcorr2_nans(Mpad(:,:,trialIx), template, [-output1(3) ; -output1(4)], maxshift);
        [motOutput(:,trialIx), corrCoeff(trialIx)] = xcorr2_nans(Mpad(:,:,trialIx), template, round(mot1'), maxshift);
        [rr,cc] = ndgrid(1:size(meanIM,1), 1:size(meanIM,2));

        for chIx = 1:size(meanIM,3)
            meanAligned(:,:,chIx,trialIx) = interp2(meanIM(:,:,chIx,trialIx), cc+motOutput(2,trialIx), rr+motOutput(1,trialIx));
        end
        actAligned(:,:,1,trialIx) = interp2(activIM(:,:,1,trialIx), cc+motOutput(2,trialIx), rr+motOutput(1,trialIx));
    end
    %clear Mpad activIM

    %identify outliers in alignment quality to determine valid trials
    ccf = corrCoeff;
    corrThresh = min(0.90, median(ccf, 'omitnan')-2*std(ccf, 'omitmissing'));
    actValidPix = squeeze(mean(~isnan(actAligned(:,:,1,:)), [1 2]));
    validTrials= find(ccf(:)>corrThresh & actValidPix(:)>mean(actValidPix)/2);
    exptSummary.meanIM{DMDix} = mean(meanAligned(:,:,:,validTrials),4, 'omitnan');
    actIM = prctile(actAligned(:,:,:,validTrials),80,4);  %mean(actAligned(:,:,:,validTrials), 4, 'omitnan');
    nanFrac = mean(isnan(actAligned(:,:,:,validTrials)), 4);
    actIM(nanFrac>0.6) = nan;
    exptSummary.actIM{DMDix} = actIM;

    %accumulate peaks, only from valid trials
    peaksCat = struct;
    for vTrialIx = 1:length(validTrials)
        trialIx = validTrials(vTrialIx);
        if ~isfield(peaksCat, 'row')
            peaksCat.row = peaks{trialIx}.row - motOutput(1,trialIx);
            peaksCat.col = peaks{trialIx}.col - motOutput(2,trialIx);
            peaksCat.val = peaks{trialIx}.val;
        else
            peaksCat.row = cat(1, peaksCat.row, peaks{trialIx}.row - motOutput(1,trialIx));
            peaksCat.col = cat(1, peaksCat.col, peaks{trialIx}.col - motOutput(2,trialIx));
            peaksCat.val = cat(1, peaksCat.val, peaks{trialIx}.val);
        end
    end

    %select sources
    %strategy 1: find peaks directly on aligned activity image
    actIM = mean(actAligned(:,:,:,validTrials), 4, 'includenan');
    actIM = actIM ./ 10^(floor(log10(max(actIM(:))))-1);
    nanFrac = mean(isnan(actAligned(:,:,:,validTrials)), 4);
    actIM(nanFrac>params.nanThresh) = nan;
    medIM = nanmedfilt2(actIM, 5.*[1 1]);
    actIM = actIM-medIM; %subtract a local baseline
    exptSummary.actIM{DMDix} = actIM;
    sz = size(actIM);

    %Mask out somata from activity image
    somaMask = false(size(actIM));
    if ~isempty(ROIs)
        for rix = 1:numel(ROIs(DMDix).roiData)
            if contains(upper(ROIs(DMDix).roiData{rix}.Label), 'SOMA')
                tmp = ROIs(DMDix).roiData{rix}.mask;
                somaMask(1:size(tmp,1), 1:size(tmp,2)) = somaMask(1:size(tmp,1), 1:size(tmp,2)) | tmp;
            end
        end
    end

    thetaf = getActImPeaks(actIM,params.peakth,somaMask,params.peakFuncOpt,params.actImHeteroscedasticNoise,params.peakBufferSize);

    sources = struct('R', [], 'C', [], 'V', []);
    totalPix = sum(~isnan(actIM(:)) & ~somaMask(:));
    if totalPix == 0 | isempty(thetaf)
        k = 0;
    else
        sources.R = round(thetaf(:,2));
        sources.C = round(thetaf(:,3));
        sources.V = thetaf(:,1);
        k = length(sources.R);
    end

    %select regions near synapses, aligned across movies
    selPix = false([sz(1:2) k]);
    params.selRadius = ceil(2*params.dXY);
    for sourceIx = k:-1:1
        rr = round(sources.R(sourceIx));
        cc = round(sources.C(sourceIx));
        selPix(rr,cc,sourceIx) = true;
        selPix(:,:,sourceIx) = imdilate(selPix(:,:,sourceIx), strel('disk',params.selRadius));
    end
    pxAlwaysValid = mean(isnan(meanAligned(:,:,1,validTrials)),4)<params.nanThresh;
    selPix = selPix & repmat(pxAlwaysValid, 1, 1, k); %ADJUST SELECTED PIXELS NOT TO INCLUDE POORLY MEASURED PIXELS

    %prune any sources that got clipped by pixel selection process
    keepSources = sum(selPix, [1 2])>5;
    if k > 0
        sources.R = sources.R(keepSources);
        sources.C = sources.C(keepSources);
    end
    selPix = selPix(:,:,keepSources);
    disp(['Number of sources: ' int2str(sum(keepSources))]);
        
    %for each file, load high res data and refine
    params.tau_full=params.tau_s*params.analyzeHz;
    params = setParamsExtractTrial(params);
    
    if isempty(ROIs) || isempty(ROIs(DMDix))
        roiData =[];
    else
        roiData = ROIs(DMDix).roiData;
    end

    if any(keepSources)
        fns = trialTable.source_extraction.fn_raw(DMDix,:);
            if strcmpi(params.microscope, 'SLAP2')
                if isfield(trialTable, 'datadr') && ~isempty(trialTable.datadr)
                    trialDataDr = trialTable.datadr;
                else
                    trialDataDr = dr;
                end
                fls = trialTable.slap2_info.first_line(DMDix,:);
                els = trialTable.slap2_info.last_line(DMDix,:);
                E = processAllTrials_Async(trialDataDr, fns, fls, els, selPix, sources, discardFrames, alignData, meanAligned, motOutput, roiData, validTrials, params);
            else %BERGAMO (registered movies live under motion_correction)
                fls = cell(1,numel(fns)); %first frame; leave empty for most uses
                els = cell(1,numel(fns)); %last frame; leave empty for most uses
                E = processAllTrials_Async(mocodr, fns, fls, els, selPix, sources, discardFrames, alignData, meanAligned, motOutput, roiData, validTrials, params);
            end

        %per-trial images
        exptSummary.E(:,DMDix) = E; %experiment data
    end
    exptSummary.selPix{DMDix} = any(selPix,3);
    exptSummary.sources{DMDix} = sources;
    exptSummary.aData(:,DMDix) = alignData;
    exptSummary.userROIs{DMDix} = roiData;
    exptSummary.peaks{DMDix}= peaks;
    exptSummary.perTrialMeanIMs{DMDix} = meanIM;
    exptSummary.perTrialMeanIMsAligned{DMDix} = meanAligned;
    exptSummary.perTrialActIms{DMDix} = actIM;
    exptSummary.perTrialActIMsAligned{DMDix} = actAligned;
    exptSummary.perTrialAlignmentOffsets{DMDix} = motOutput; %the alignment vector for each trial

    clear meanAligned meanIM actAligned F0selDS E
end

% Shut down the parallel pool explicitly here so all thread-pool arrays are
% fully materialised into regular MATLAB memory before the HDF5 saves.
% The pause gives the pool time to fully release shared memory before h5write.
delete(gcp('nocreate'));
pause(5);

params.endTime = char(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ss.SSSZZZZZ'));

trialTable.source_extraction.analysis_params = params;

%prepare file for saving
exptSummary.params = params;
exptSummary.trialTable = trialTable;
exptSummary.dr = dr;

%save (with retry so a transient HDF5 error does not discard all results)
trySave(@() saveStructToH5(trialTable, [dr filesep trialTablefn]),          'trial_table');
trySave(@() saveExperimentSummaryH5(fullfile(savedr, 'experiment_summary.h5'), exptSummary, trialTable), 'experiment_summary');
trySave(@() savePerTrialSummaryH5(  fullfile(savedr, 'per_trial_summary.h5'),  exptSummary, trialTable), 'per_trial_summary');

%verify the saved file is readable and non-empty
expSumFn = fullfile(savedr, 'experiment_summary.h5');
d = dir(expSumFn);
if isempty(d) || d.bytes == 0
    fprintf(2, 'WARNING: experiment_summary.h5 is missing or empty after save.\n');
else
    fprintf('experiment_summary.h5 written (%d MB)\n', round(d.bytes/1e6));
    % if sources were found, spot-check that each trace dataset is readable
    for DMDix = 1:numel(exptSummary.sources)
        if isempty(exptSummary.sources{DMDix}) || ~isfield(exptSummary.sources{DMDix}, 'R') ...
                || isempty(exptSummary.sources{DMDix}.R)
            continue
        end
        datasetPath = sprintf('/Path%d/sources/temporal/dF_denoised', DMDix);
        try
            info = h5info(expSumFn, datasetPath);
            fprintf('  %s shape: %s\n', datasetPath, mat2str(info.Dataspace.Size));
        catch
            fprintf('  %s not found.\n', datasetPath);
        end
    end
end


disp('Done summarize_LoCo')
end

function trySave(saveFcn, label, maxAttempts)
%TRYSAVE  Call saveFcn up to maxAttempts times, pausing between failures.
% Note: retries only help with transient I/O errors. Failures caused by
% stale thread-pool state in the current process will not recover across
% retries.
if nargin < 3 || isempty(maxAttempts)
    maxAttempts = 3;
end
for attempt = 1:maxAttempts
    try
        saveFcn();
        return;
    catch ME
        fprintf(2, 'WARNING: Attempt %d/%d to save "%s" failed: %s\n', ...
            attempt, maxAttempts, label, ME.message);
        if attempt < maxAttempts
            % Long pause to allow the thread pool to fully release shared
            % memory asynchronously — the taint clears once shutdown completes.
            fprintf(2, 'Waiting 30s before retry...\n');
            pause(30);
        else
            rethrow(ME);
        end
    end
end
end
