function trialTable = buildTrialTable(dr, savedr, useAllFiles, fns)
%BUILDTRIALTABLE Organize multi-trial recordings and metadata (non-SLAP2).
%   trialTable = BUILDTRIALTABLE(dr, savedr, useAllFiles, fns) builds the trial_table
%   struct documented in README.md and writes it to
%   fullfile(savedr, 'trial_table.h5'). nDMDs / imaging paths is 1 for non-SLAP2 data.

if nargin < 1 || isempty(dr)
    dr = uigetdir;
end
if nargin < 2 || isempty(savedr)
    savedr = dr;
end
if nargin < 3 || isempty(useAllFiles)
    useAllFiles = false;
end
if nargin < 4
    fns = [];
end

if isempty(fns)
    unpickedfiles = collectTrialSourceFiles(dr, false);
    if useAllFiles
        epoch = 1;
        epochfiles{1} = {unpickedfiles.name};
    else
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
    end
elseif (ischar(fns) || isstring(fns)) && contains(fns, '.h5')
    epoch = 1;
    epochfiles{1} = {fns};
elseif ~iscell(fns) && (((ischar(fns) || isstring(fns)) && contains(fns, '.tif')) || isequal(fns, true)) %generate an autoTrialTable with all files
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

function files = collectTrialSourceFiles(dr, excludeDerived)
%COLLECTTRIALSOURCEFILES List .tif and .h5 movie candidates in a directory.
if nargin < 2 || isempty(excludeDerived)
    excludeDerived = false;
end
dTif = dir([dr filesep '*.tif']);
dH5 = dir([dr filesep '*.h5']);
files = [dTif; dH5];
if isempty(files)
    return
end
[~, ord] = sort({files.name});
files = files(ord);
if excludeDerived
    nm = {files.name};
    mask = ~contains(nm, 'REGISTERED') & ~strcmpi(nm, 'trial_table.h5');
    files = files(mask);
end
end
