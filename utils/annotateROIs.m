function annotateROIs(dr_or_pathToTrialTable)

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

%confirm that all files exist (also populates source_extraction.fn_raw)
[trialTable, keepTrials] = verifyFiles(trialTablefn, dr);
mocodr = fullfile(trialTable.savedr, 'motion_correction');
% for dmdKey = fieldnames(trialTable.slap2_info.ref_stack)'
%     trialTable.slap2_info.ref_stack.(dmdKey{1}).IM = []; %this uses a lot of memory and we won't need it
% end
nDMDs = size(trialTable.filename,1); %the trial table has size #DMDs x # trials; Bergamo is treated as '1 DMD'
nTrials = size(trialTable.filename,2);

disp(['## ANNOTATING' newline 'Folder:'])
disp(dr)

savedr = fullfile(trialTable.savedr, 'annotations');

if ~exist(savedr, 'dir')
    mkdir(savedr);
end

%call up a GUI for the user to define Soma ROI and regions to exclude
fnAnnH5 = [savedr filesep 'annotations.h5'];
if exist(fnAnnH5, 'file')
    ROIs = loadAnnotationsH5(fnAnnH5);
else
    for DMDix = 1:nDMDs
        %load image data
        firstValidTrial = find(keepTrials(DMDix,:),1,"first");
        [~, fn, ext] = fileparts(trialTable.motion_correction.fn_reg_ds{DMDix,firstValidTrial});
        [IM, ~] = ScanImageTiffWrapper(fullfile(mocodr, [fn ext]));
        IM = squeeze(mean(IM,[3 4], 'omitnan'));
        hROIs(DMDix) = drawROIs(sqrt(max(0,IM)), savedr, fn);
        ROIs(DMDix).dr = mocodr;
        ROIs(DMDix).fn = fn;
    end
    for DMDix = 1:nDMDs
        waitfor(hROIs(DMDix).hF);
        ROIs(DMDix).roiData = hROIs(DMDix).roiData;
    end
    saveAnnotationsH5(fnAnnH5, ROIs); clear hROIs;
end
