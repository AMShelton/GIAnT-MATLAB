function [trialTable, keepTrials] = verifyFiles(fn,dr, params)

load([dr filesep fn], 'trialTable');

mocodr = [trialTable.savedr filesep 'motion_correction'];
datadr = trialTable.datadr;

nTrials = length(trialTable.trueTrialIx);
nDMDs = size(trialTable.filename,1);
keepTrials = true(nDMDs, nTrials);
for trialIx = nTrials:-1:1
    for DMDix = 1:nDMDs
        [~, tiffFn, ext] = fileparts(trialTable.fnRegDS{DMDix,trialIx}); 
        if isempty(dir([mocodr filesep tiffFn '.tif'])) & isempty(dir([mocodr filesep tiffFn '.h5']))
            disp(['Missing tiff or h5 file:' tiffFn])
            keepTrials(DMDix,trialIx) = false;
        else
            trialTable.fnRegDS{DMDix,trialIx} = [tiffFn, ext];
        end

        [~, alignFn] = fileparts(trialTable.fnAdata{DMDix,trialIx}); 
        if ~exist([mocodr filesep alignFn '.mat'], 'file')
            disp(['Missing alignData file:' alignFn])
            keepTrials(DMDix,trialIx) = false;
        else
            load([mocodr filesep alignFn '.mat'], 'aData');
            if isfield(aData, 'registrationFailed') && aData.registrationFailed
                disp(['Registration failed for file:' alignFn])
                keepTrials(DMDix,trialIx) = false;
            else
                trialTable.fnAdata{DMDix,trialIx} = [alignFn '.mat'];
            end
        end

        sourceFn = trialTable.filename{DMDix,trialIx};
        if ~exist([datadr filesep sourceFn], 'file')
            disp(['Missing source data file:' sourceFn])
            keepTrials(DMDix, trialIx) = false;
        end
        [~,~,ext] = fileparts(sourceFn);
        if strcmpi(ext, '.dat')
            trialTable.fnRaw{DMDix,trialIx} = sourceFn;
        else
            rawFn = trialTable.fnRaw{DMDix,trialIx};
            if ~exist([datadr filesep rawFn], 'file')
                disp(['Missing raw data file:' rawFn])
                keepTrials(DMDix, trialIx) = false;
            end
        end
    end
end
if ~all(keepTrials)
    disp(['Files were missing for ' int2str(sum(~keepTrials(:))) ' recordings; likely failed alignments. Proceeding without them.']);
end
if ~any(keepTrials)
    error('All trials were rejected due to missing alignment files!');
end
end