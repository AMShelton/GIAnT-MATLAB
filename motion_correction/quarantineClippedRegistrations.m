function moved = quarantineClippedRegistrations(mocodr, varargin)
%QUARANTINECLIPPEDREGISTRATIONS Set aside registrations made with the NaN-destroying clip.
%
%   moved = quarantineClippedRegistrations(mocodr)
%   moved = quarantineClippedRegistrations(mocodr, 'DryRun', true)
%
%   MultiRoiRegistration commits a1099e5..a87ff75 (2026-11-13) clipped negative
%   raw pixels with max(x,0), which also turned every unscanned NaN pixel into
%   0. Registrations produced by those versions used a modified correlation
%   statistic and must be redone. They are recognisable by the dataset
%   /negativePixelFraction in the alignment h5 without the marker
%   /clipKeepsNaN that the fixed version (de204b1+) writes. 'Before' (a
%   datetime) additionally restricts to files modified before that time.
%
%   For each affected trial the *_ALIGNMENTDATA.h5 and its
%   *_REGISTERED_DOWNSAMPLED-*Hz.tif are moved into
%   <mocodr>/_redo_nanclip_<stamp>/. MultiRoiRegistration with
%   overwriteExisting = false then re-registers exactly those trials.
%
%   Options: 'DryRun' (false), 'Before' (datetime; default: no limit).

opts = struct('DryRun', false, 'Before', NaT);
for k = 1:2:numel(varargin), opts.(varargin{k}) = varargin{k+1}; end

d = dir(fullfile(mocodr, '*_ALIGNMENTDATA.h5'));
stamp = datestr(now, 'yyyymmdd_HHMMSS');
qdir = fullfile(mocodr, ['_redo_nanclip_' stamp]);
moved = {};
for k = 1:numel(d)
    h5path = fullfile(d(k).folder, d(k).name);
    if ~isnat(opts.Before) && datetime(d(k).datenum, 'ConvertFrom', 'datenum') >= opts.Before
        continue
    end
    try
        h5info(h5path, '/negativePixelFraction');
    catch
        continue                                    % pre-clip registration: fine
    end
    try
        h5info(h5path, '/clipKeepsNaN');
        continue                                    % fixed version: fine
    catch
    end
    prefix = erase(d(k).name, '_ALIGNMENTDATA.h5');
    tifs = dir(fullfile(mocodr, [prefix '_REGISTERED_DOWNSAMPLED-*Hz.tif']));
    files = [{h5path}, fullfile({tifs.folder}, {tifs.name})];
    fprintf('%s%s\n', prefix, ternary(opts.DryRun, '  (would move)', ''));
    if ~opts.DryRun
        if ~exist(qdir, 'dir'), mkdir(qdir); end
        for f = files
            movefile(f{1}, fullfile(qdir, filesep));
        end
    end
    moved(end+1) = {prefix}; %#ok<AGROW>
end
fprintf('%d affected registration(s)%s\n', numel(moved), ternary(opts.DryRun, ' - dry run, nothing moved', [' moved to ' qdir]));
if ~isempty(moved) && ~opts.DryRun
    fprintf('Re-run MultiRoiRegistration on this trial table with overwriteExisting = false; only these trials are redone.\n');
end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
