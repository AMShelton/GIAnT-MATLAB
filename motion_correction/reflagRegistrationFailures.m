function report = reflagRegistrationFailures(trialTablePath, maxMotionStd_px, varargin)
%REFLAGREGISTRATIONFAILURES Recompute the "too much motion" flag of saved registrations.
%
%   report = reflagRegistrationFailures(trialTablePath, maxMotionStd_px)
%   report = reflagRegistrationFailures(trialTablePath, maxMotionStd_px, 'DryRun', true)
%
%   MultiRoiRegistration marks a trial registrationFailed when the standard
%   deviation of its downsampled shift trace (motionDSc / motionDSr) exceeds
%   a threshold - hard-coded at 1.5 px until 2026-11-13, now
%   params.maxMotionStd_px. verifyFiles then removes every flagged trial from
%   source extraction, even though the registration ran to completion and the
%   registered movie + *_ALIGNMENTDATA.h5 are on disk. Because the shift
%   traces are saved, the decision can be re-made afterwards with a different
%   threshold without re-registering anything. This function does that:
%
%     1. loads the trial table (loadStructFromH5),
%     2. for every (DMD, trial) reads /motionDSc and /motionDSr from the
%        alignment file named in motion_correction.fn_adata, computes
%        std() exactly as MultiRoiRegistration does (plain std; a NaN std
%        never flags) and derives newFlag = any(std > maxMotionStd_px),
%     3. rewrites /registrationFailed (int8) in the alignment file and writes
%        /motionStd_px, /maxMotionStd_px (created when absent),
%     4. updates motion_correction.registration_failed in the trial table,
%        records the threshold in motion_correction.align_params.maxMotionStd_px,
%        and saves it (saveStructToH5) after copying the original to
%        <trial_table>_backup_reflag_<yyyymmdd_HHMMSS>.h5,
%     5. writes a per-trial CSV next to the trial table
%        (reflag_registration_<stamp>.csv) with before/after values.
%
%   Trials whose alignment file is missing, or whose shift traces are absent
%   (registration aborted before writing them), keep their existing flag and
%   are reported with reason 'no_alignment_file' / 'no_motion_trace'.
%   Trials that are flagged for a different reason are not distinguishable
%   from motion flags in old files; they are re-evaluated on motion alone,
%   which is what the registration itself does when it completes.
%
%   Name/value options:
%     'DryRun'      false   compute and report only; touch no file
%     'Backup'      true    copy the trial table before overwriting it
%     'Verbose'     true    print the per-DMD before/after summary
%
%   The returned report is a table with one row per (DMD, trial):
%     dmd, trial, adata_file, std_c_px, std_r_px, flag_before, flag_after,
%     changed, reason.
%
%   After re-flagging, re-run source extraction (SILo) for the session;
%   registration does not need to be repeated.

opts = struct('DryRun', false, 'Backup', true, 'Verbose', true);
for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~isfield(opts, name)
        error('reflagRegistrationFailures:BadOption', 'Unknown option "%s".', name);
    end
    opts.(name) = varargin{k+1};
end
validateattributes(maxMotionStd_px, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, mfilename, 'maxMotionStd_px');
maxMotionStd_px = double(maxMotionStd_px);

if nargin < 1 || isempty(trialTablePath)
    [fn, dr] = uigetfile('*.h5', 'Select a trial_table file', '*trial_table*.h5');
    if isequal(fn, 0), report = table(); return; end
    trialTablePath = fullfile(dr, fn);
end
if ~exist(trialTablePath, 'file')
    error('reflagRegistrationFailures:FileNotFound', 'Trial table not found: %s', trialTablePath);
end
[ttDir, ttName] = fileparts(trialTablePath);

trialTable = loadStructFromH5(trialTablePath);
if ~isfield(trialTable, 'motion_correction') || ~isfield(trialTable.motion_correction, 'fn_adata')
    error('reflagRegistrationFailures:NotRegistered', 'Trial table has no motion_correction.fn_adata; run registration first.');
end
mocodr = fullfile(trialTable.savedr, 'motion_correction');
if ~exist(mocodr, 'dir')
    % the data may have moved since registration: fall back to the folder next to the trial table
    alt = fullfile(ttDir, 'motion_correction');
    if exist(alt, 'dir')
        warning('reflagRegistrationFailures:MovedData', 'savedr motion_correction folder not found; using %s', alt);
        mocodr = alt;
    else
        error('reflagRegistrationFailures:NoMocoDir', 'motion_correction folder not found: %s', mocodr);
    end
end

nDMDs = size(trialTable.filename, 1);
nTrials = size(trialTable.true_trial_ix, 2);
fnAdata = trialTable.motion_correction.fn_adata;
hasTable = isfield(trialTable.motion_correction, 'registration_failed') ...
    && isequal(size(trialTable.motion_correction.registration_failed), [nDMDs, nTrials]);
if hasTable
    flagBefore = logical(trialTable.motion_correction.registration_failed);
else
    flagBefore = false(nDMDs, nTrials);
end
flagAfter = flagBefore;

n = nDMDs * nTrials;
dmd = zeros(n, 1); trial = zeros(n, 1); adataFile = cell(n, 1);
stdC = nan(n, 1); stdR = nan(n, 1); before = false(n, 1); after = false(n, 1); reason = cell(n, 1);
pendingWrites = cell(0, 3);   % {path, flag, motionStd}

row = 0;
for DMDix = 1:nDMDs
    for trialIx = 1:nTrials
        row = row + 1;
        dmd(row) = DMDix; trial(row) = trialIx;
        before(row) = flagBefore(DMDix, trialIx);
        after(row) = before(row);
        reason{row} = '';
        if size(fnAdata, 1) < DMDix || size(fnAdata, 2) < trialIx || isempty(fnAdata{DMDix, trialIx})
            adataFile{row} = ''; reason{row} = 'no_alignment_file'; continue
        end
        [~, alignFn] = fileparts(fnAdata{DMDix, trialIx});
        adataPath = fullfile(mocodr, [alignFn '.h5']);
        adataFile{row} = [alignFn '.h5'];
        if ~exist(adataPath, 'file')
            reason{row} = 'no_alignment_file'; continue
        end
        if ~hasTable
            % old trial table: the flag lives only in the alignment file
            try
                before(row) = logical(h5read(adataPath, '/registrationFailed'));
            catch
                before(row) = false;
            end
            flagBefore(DMDix, trialIx) = before(row);
            after(row) = before(row);
        end
        try
            mc = double(h5read(adataPath, '/motionDSc'));
            mr = double(h5read(adataPath, '/motionDSr'));
        catch
            reason{row} = 'no_motion_trace'; continue
        end
        if isempty(mc) || isempty(mr) || all(isnan(mc)) || all(isnan(mr))
            reason{row} = 'no_motion_trace'; continue
        end
        motionStd = [std(mc(:)), std(mr(:))];       % same statistic as MultiRoiRegistration
        stdC(row) = motionStd(1); stdR(row) = motionStd(2);
        newFlag = any(motionStd > maxMotionStd_px);
        after(row) = newFlag;
        flagAfter(DMDix, trialIx) = newFlag;
        if newFlag && ~before(row)
            reason{row} = 'now_flagged';
        elseif ~newFlag && before(row)
            reason{row} = 'now_accepted';
        elseif newFlag
            reason{row} = 'still_flagged';
        else
            reason{row} = 'unchanged';
        end
        pendingWrites(end+1, :) = {adataPath, newFlag, motionStd}; %#ok<AGROW>
    end
end

report = table(dmd, trial, adataFile, stdC, stdR, before, after, before ~= after, reason, ...
    'VariableNames', {'dmd', 'trial', 'adata_file', 'std_c_px', 'std_r_px', 'flag_before', 'flag_after', 'changed', 'reason'});

if opts.Verbose
    fprintf('%s: maxMotionStd_px = %.3g (legacy hard-coded value 1.5)\n', ttName, maxMotionStd_px);
    for DMDix = 1:nDMDs
        m = report.dmd == DMDix;
        ev = m & ~isnan(report.std_c_px);
        fprintf('  DMD%d: %d trials; flagged before %d, after %d (%d accepted, %d newly flagged); %d without usable motion trace\n', ...
            DMDix, nnz(m), nnz(report.flag_before(m)), nnz(report.flag_after(m)), ...
            nnz(report.flag_before(m) & ~report.flag_after(m)), nnz(~report.flag_before(m) & report.flag_after(m)), nnz(m & ~ev));
        if any(ev)
            sc = report.std_c_px(ev); sr = report.std_r_px(ev);
            fprintf('        shift std (px): col median %.2f max %.2f; row median %.2f max %.2f\n', ...
                median(sc), max(sc), median(sr), max(sr));
        end
    end
end

if opts.DryRun
    if opts.Verbose, fprintf('  dry run: nothing written\n'); end
    return
end

% 1) alignment files
for k = 1:size(pendingWrites, 1)
    adataPath = pendingWrites{k, 1};
    writeOrCreate(adataPath, '/registrationFailed', int8(pendingWrites{k, 2}), 'int8');
    writeOrCreate(adataPath, '/motionStd_px', pendingWrites{k, 3}, 'double');
    writeOrCreate(adataPath, '/maxMotionStd_px', maxMotionStd_px, 'double');
end

% 2) trial table
stamp = datestr(now, 'yyyymmdd_HHMMSS');
if opts.Backup
    backupPath = fullfile(ttDir, [ttName '_backup_reflag_' stamp '.h5']);
    copyfile(trialTablePath, backupPath);
    if opts.Verbose, fprintf('  trial table backed up to %s\n', backupPath); end
end
trialTable.motion_correction.registration_failed = flagAfter;
if ~isfield(trialTable.motion_correction, 'align_params') || ~isstruct(trialTable.motion_correction.align_params)
    trialTable.motion_correction.align_params = struct();
end
trialTable.motion_correction.align_params.maxMotionStd_px = maxMotionStd_px;
trialTable.motion_correction.reflag_timestamp = stamp;
saveStructToH5(trialTable, trialTablePath);

% 3) report
csvPath = fullfile(ttDir, ['reflag_registration_' stamp '.csv']);
writetable(report, csvPath);
if opts.Verbose
    fprintf('  wrote %s\n  trial table updated; re-run source extraction (SILo) for this session - registration does not need to be repeated.\n', csvPath);
end
end


function writeOrCreate(filename, path, val, dtype)
%WRITEORCREATE h5write into an existing dataset, creating it when absent.
try
    info = h5info(filename, path);
    sz = double(info.Dataspace.Size);
    if ~isequal(sz(:)', size(val))
        % the stored dataset has the wrong shape (should not happen for these
        % scalars/1x2) - recreate under the same name is impossible in HDF5,
        % so write what fits and warn.
        warning('reflagRegistrationFailures:SizeMismatch', '%s:%s has size [%s], value [%s]; skipped', ...
            filename, path, num2str(sz), num2str(size(val)));
        return
    end
catch
    h5create(filename, path, size(val), 'Datatype', dtype);
end
h5write(filename, path, cast(val, dtype));
end
