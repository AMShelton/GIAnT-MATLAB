function report = validateBatchedSlap2Reads(datPath,channels,frames,dt,zPlane,spTypeFlag)
%VALIDATEBATCHEDSLAP2READS Compare getImages against repeated getImage.
%
% Example:
%   report = validateBatchedSlap2Reads(datPath,[1 2],frames,ceil(dt),1,1)
%
% This is a manual real-data validation helper for the MultiROI batched-read
% optimization. It does not modify any files.

if nargin<6, spTypeFlag = 1; end
if nargin<5, zPlane = 1; end

sdf = slap2.Slap2DataFile(datPath);
frames = frames(:)';
channels = channels(:)';

if spTypeFlag
    [Ybatch,Fbatch] = sdf.getImages(channels,frames,dt,zPlane,spTypeFlag);
else
    [Ybatch,Fbatch] = sdf.getImages(channels,frames,dt,zPlane);
end

h = size(Ybatch,1);
w = size(Ybatch,2);
Ybatch = reshape(Ybatch,h,w,numel(channels),numel(frames));
Fbatch = reshape(Fbatch,h,w,numel(frames));

Yref = nan(size(Ybatch),'like',Ybatch);
Fref = nan(size(Fbatch),'like',Fbatch);

for fIx = 1:numel(frames)
    for cIx = 1:numel(channels)
        if spTypeFlag
            [im,~,fresh] = sdf.getImage(channels(cIx),frames(fIx),dt,zPlane,spTypeFlag);
        else
            [im,~,fresh] = sdf.getImage(channels(cIx),frames(fIx),dt,zPlane);
        end
        Yref(:,:,cIx,fIx) = im;
        if cIx==1
            Fref(:,:,fIx) = fresh;
        end
    end
end

dY = abs(double(Ybatch)-double(Yref));
dF = abs(double(Fbatch)-double(Fref));

report = struct();
report.maxAbsImageDifference = max(dY,[],'all','omitnan');
report.maxAbsFreshnessDifference = max(dF,[],'all','omitnan');
report.identicalNaNMaskImages = isequal(isnan(Ybatch),isnan(Yref));
report.identicalNaNMaskFreshness = isequal(isnan(Fbatch),isnan(Fref));
report.nFrames = numel(frames);
report.nChannels = numel(channels);

disp(report)
end
