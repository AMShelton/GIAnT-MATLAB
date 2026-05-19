function saveAnnotationsH5(filename, ROIs)
%SAVEANNOTATIONSH5 Save manual ROI annotations to an HDF5 file.
%
% File schema:
%   /Path1/dr
%   /Path1/fn
%   /Path1/roi_001/type
%   /Path1/roi_001/label
%   /Path1/roi_001/mask
%   /Path1/roi_001/position (polygon only)
%   /Path1/roi_001/center (circle/ellipse)
%   /Path1/roi_001/semi_axes (ellipse)
%   /Path1/roi_001/rotation_angle (ellipse)
%   /Path1/roi_001/radius (circle)

if nargin < 2
    error('saveAnnotationsH5:MissingInput', 'filename and ROIs are required.');
end

if exist(filename, 'file')
    delete(filename);
end

for DMDix = 1:numel(ROIs)
    pathRoot = sprintf('/Path%d', DMDix);

    if isfield(ROIs(DMDix), 'dr')
        writeString(filename, [pathRoot '/dr'], ROIs(DMDix).dr);
    else
        writeString(filename, [pathRoot '/dr'], '');
    end

    if isfield(ROIs(DMDix), 'fn')
        writeString(filename, [pathRoot '/fn'], ROIs(DMDix).fn);
    else
        writeString(filename, [pathRoot '/fn'], '');
    end

    if isfield(ROIs(DMDix), 'roiData') && ~isempty(ROIs(DMDix).roiData)
        roiData = ROIs(DMDix).roiData;
    else
        roiData = {};
    end
    writeDataset(filename, [pathRoot '/n_rois'], uint32(numel(roiData)));

    for rix = 1:numel(roiData)
        roiPath = sprintf('%s/roi_%03d', pathRoot, rix);
        S = roiData{rix};

        writeString(filename, [roiPath '/type'], normalizeType(getFieldOrDefault(S, 'Type', '')));
        writeString(filename, [roiPath '/label'], getFieldOrDefault(S, 'Label', ''));
        writeDataset(filename, [roiPath '/mask'], uint8(logical(getFieldOrDefault(S, 'mask', false(0, 0)))));

        if isfield(S, 'Position') && ~isempty(S.Position)
            writeDataset(filename, [roiPath '/position'], double(S.Position));
        end
        if isfield(S, 'Center') && ~isempty(S.Center)
            writeDataset(filename, [roiPath '/center'], double(S.Center));
        end
        if isfield(S, 'SemiAxes') && ~isempty(S.SemiAxes)
            writeDataset(filename, [roiPath '/semi_axes'], double(S.SemiAxes));
        end
        if isfield(S, 'RotationAngle') && ~isempty(S.RotationAngle)
            writeDataset(filename, [roiPath '/rotation_angle'], double(S.RotationAngle));
        end
        if isfield(S, 'Radius') && ~isempty(S.Radius)
            writeDataset(filename, [roiPath '/radius'], double(S.Radius));
        end
    end
end
end

function out = getFieldOrDefault(S, fieldName, defaultValue)
if isfield(S, fieldName) && ~isempty(S.(fieldName))
    out = S.(fieldName);
else
    out = defaultValue;
end
end

function writeString(filename, path, value)
if isstring(value)
    value = char(value);
end
if isempty(value)
    encoded = uint16([]);
else
    encoded = uint16(value);
end
writeDataset(filename, path, encoded);
end

function writeDataset(filename, path, value)
if isempty(value)
    return
else
    h5create(filename, path, size(value), 'Datatype', class(value));
    h5write(filename, path, value);
end
end

function typeOut = normalizeType(typeIn)
switch lower(char(typeIn))
    case {'images.roi.polygon', 'polygon'}
        typeOut = 'polygon';
    case {'images.roi.circle', 'circle'}
        typeOut = 'circle';
    case {'images.roi.ellipse', 'ellipse'}
        typeOut = 'ellipse';
    otherwise
        typeOut = char(typeIn);
end
end
