function trialTable = buildTrialTable(dr, fns, savedr)
%BUILDTRIALTABLE Organize multi-trial recordings and metadata for Bergamo.
%   trialTable = BUILDTRIALTABLE(dr, fns, savedr) builds the trial_table
%   struct documented in README.md and writes it to
%   fullfile(savedr, 'trial_table.h5'). nDMDs is 1 for Bergamo data.

if ~nargin
    dr = uigetdir;
end
if nargin<3
    savedr = dr;
end
if nargin<2
    unpickedfiles = dir([dr filesep '*.tif']);

    epoch = 0;
    while ~isempty(unpickedfiles)
        [indx,tf] = listdlg('ListString',{unpickedfiles.name}, 'PromptString',['Select files for EPOCH ' int2str(epoch)]);
        if ~tf
            break
        end
        epoch = epoch+1;
        epochfiles{epoch} = {unpickedfiles(indx).name};
        unpickedfiles(indx) = [];
    end
elseif contains(fns, '.h5')
    epoch = 1;
    epochfiles{1} = {fns};
elseif ~iscell(fns) && (contains(fns, '.tif') || fns==true) %generate an autoTrialTable with all files
    %select all tif files in folder that are not REGISTERED and put them in
    %a single epoch
    epoch = 1;
    files = dir([dr filesep '*.tif']);
    files = files(~contains({files.name}, 'REGISTERED') & ~contains({files.name}, 'FIGURE'));
    epochfiles{1} = {files.name};
else %files were passed to generate an autoTrialTable
    epoch = 1;
    epochfiles{1} = fns;
end

trialTable.datadr = dr;
trialTable.savedr = savedr;

nDMDs = 1;
trialTable.filename = {};

trueTrialIx = 0;
for eIx = 1:epoch %for each epoch
    files = epochfiles{eIx};
    for fIx = 1:length(files)
        trueTrialIx = trueTrialIx+1;
        trialTable.filename{1,trueTrialIx} = files{fIx};
        trialTable.true_trial_ix(1:nDMDs, trueTrialIx) = trueTrialIx;
        trialTable.epoch(1:nDMDs, trueTrialIx) = eIx;
    end
end

saveStructToH5(trialTable, fullfile(savedr, 'trial_table.h5'));
end
