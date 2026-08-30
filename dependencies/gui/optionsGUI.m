function optsOut = optionsGUI(opts, tooltips, funcName)
%OPTIONSGUI Responsive parameter editor for GIAnT.
%
% The GUI is laid out relative to the current MATLAB monitor rather than at
% a fixed screen position. If the parameter list is too tall to fit on the
% current display (common over Remote Desktop), options are automatically
% split across multiple columns.
%
% Saved presets are merged into the current option schema. This keeps older
% presets usable when new parameters are added to setParams.m.

if nargin > 2 && ~isempty(funcName)
    caller = char(string(funcName));
else
    callerStack = dbstack;
    if numel(callerStack) > 1
        caller = callerStack(2).name;
    else
        caller = 'Unknown Function';
    end
end

if nargin < 2 || isempty(tooltips)
    tooltips = struct();
end

if ~isstruct(opts) || ~isscalar(opts)
    error('optionsGUI:InvalidOptions', ...
        'opts must be a scalar structure.');
end

% Preserve the schema supplied by setParams. Loading an old preset should
% modify values, not replace the list of currently supported parameters.
schemaOpts = opts;
optsOut = opts;

optNames = sort(fieldnames(schemaOpts));
N = numel(optNames);

%% Responsive layout
% Pixel dimensions are intentionally compact so the GUI remains usable in
% typical 1366x768 / 1600x900 Remote Desktop sessions.
rowH = 22;
rowGap = 3;
rowStep = rowH + rowGap;
bottomH = 48;
topPad = 12;

labelW = 155;
editW = 165;
resetW = 22;
colGap = 16;
colW = labelW + editW + resetW + 18;

monitorPos = getTargetMonitor();
screenMarginX = 20;
screenMarginY = 45;

availableH = max(300, monitorPos(4) - 2*screenMarginY);
maxRows = max(1, floor((availableH - bottomH - topPad) / rowStep));
nRows = min(N, maxRows);
nCols = max(1, ceil(N / nRows));

% If the first layout is wider than the monitor, compact the controls.
availableW = max(500, monitorPos(3) - 2*screenMarginX);
figW = nCols*colW + (nCols-1)*colGap + 20;
if figW > availableW
    editW = max(110, editW - ceil((figW-availableW)/max(1,nCols)));
    colW = labelW + editW + resetW + 18;
    figW = nCols*colW + (nCols-1)*colGap + 20;
end

figH = bottomH + topPad + nRows*rowStep + 8;
figH = min(figH, availableH);

% Explicitly keep the complete window inside the selected monitor.
figX = monitorPos(1) + max(screenMarginX, floor((monitorPos(3)-figW)/2));
figY = monitorPos(2) + max(screenMarginY, floor((monitorPos(4)-figH)/2));

handles.F = figure( ...
    'Name', caller, ...
    'Units', 'pixels', ...
    'Position', [figX figY figW figH], ...
    'Toolbar', 'none', ...
    'Menubar', 'none', ...
    'Resize', 'off', ...
    'NumberTitle', 'off', ...
    'WindowStyle', 'normal');

handles.load = uicontrol( ...
    'Units','pixels', ...
    'Parent',handles.F, ...
    'Style','pushbutton', ...
    'Position',[80 12 60 24], ...
    'String','Load', ...
    'Callback',@loadButton);

handles.save = uicontrol( ...
    'Units','pixels', ...
    'Parent',handles.F, ...
    'Style','pushbutton', ...
    'Position',[12 12 60 24], ...
    'String','Save', ...
    'Callback',@saveButton);

handles.OK = uicontrol( ...
    'Units','pixels', ...
    'Parent',handles.F, ...
    'Style','pushbutton', ...
    'Position',[figW-92 12 80 24], ...
    'String','OK', ...
    'Callback',@OK);

handles.titles = gobjects(N,1);
handles.reset = gobjects(N,1);
handles.ET = gobjects(N,1);

for n = 1:N
    [xLabel, xEdit, xReset, y] = controlPosition(n);

    handles.titles(n) = uicontrol( ...
        'Units','pixels', ...
        'Parent',handles.F, ...
        'Style','text', ...
        'HorizontalAlignment','right', ...
        'Position',[xLabel y-1 labelW rowH], ...
        'String',optNames{n});

    handles.reset(n) = uicontrol( ...
        'Units','pixels', ...
        'Parent',handles.F, ...
        'Style','pushbutton', ...
        'Position',[xReset y resetW rowH], ...
        'String','R', ...
        'TooltipString',['Reset ' optNames{n}], ...
        'Callback',@(varargin) reset(n));

    reset(n);
end

% Bring the window to the foreground after construction. This is useful
% when MATLAB is running inside an RDP session with several open figures.
figure(handles.F);
drawnow;
waitfor(handles.F);

    function [xLabel, xEdit, xReset, y] = controlPosition(n)
        colIx = floor((n-1)/nRows);
        rowIx = mod(n-1,nRows);

        x0 = 10 + colIx*(colW+colGap);
        xLabel = x0;
        xEdit = xLabel + labelW + 8;
        xReset = xEdit + editW + 4;

        % First alphabetic option appears at the top.
        yTop = figH - topPad - rowH;
        y = yTop - rowIx*rowStep;
    end

    function parseET(src,n)
        fieldName = optNames{n};
        valueType = class(opts.(fieldName));
        set(handles.titles(n),'ForegroundColor','k');

        try
            switch valueType
                case 'logical'
                    stringsIn = get(src,'String');
                    valueIx = get(src,'Value');
                    optsOut.(fieldName) = strcmpi(stringsIn{valueIx},'true');

                case 'double'
                    txt = get(src,'String');
                    value = str2num(txt); %#ok<ST2NM>
                    if isempty(value) && ~isempty(strtrim(txt))
                        error('Could not parse numeric value.');
                    end
                    optsOut.(fieldName) = value;

                case 'cell'
                    stringsIn = get(src,'String');
                    valueIx = get(src,'Value');
                    selected = stringsIn{valueIx};
                    % Preserve legacy behavior for cell options containing
                    % MATLAB literals such as quoted strings.
                    try
                        optsOut.(fieldName) = eval(selected); %#ok<EVLDIR>
                    catch
                        optsOut.(fieldName) = selected;
                    end

                case 'char'
                    optsOut.(fieldName) = get(src,'String');

                case 'string'
                    optsOut.(fieldName) = string(get(src,'String'));

                otherwise
                    error('Unsupported parameter type "%s".',valueType);
            end
        catch ME
            set(handles.titles(n),'ForegroundColor','r');
            warning('optionsGUI:InvalidValue', ...
                'Could not update "%s": %s',fieldName,ME.message);
        end
    end

    function saveButton(varargin)
        parseAllControls();

        [fn,path] = uiputfile('*.mat','Save parameter preset');
        if isequal(fn,0) || isequal(path,0)
            return
        end

        save(fullfile(path,fn),'optsOut');
    end

    function loadButton(varargin)
        [fn,path] = uigetfile('*.mat','Load parameter preset');
        if isequal(fn,0) || isequal(path,0)
            return
        end

        loadedFile = load(fullfile(path,fn));
        loadedOpts = extractLoadedOptions(loadedFile);

        % Merge the preset into the current schema. New parameters retain
        % their current/default values when absent from an older preset.
        mergedOpts = schemaOpts;
        loadedNames = fieldnames(loadedOpts);
        ignored = strings(0,1);

        for k = 1:numel(loadedNames)
            fieldName = loadedNames{k};
            if isfield(mergedOpts,fieldName)
                mergedOpts.(fieldName) = loadedOpts.(fieldName);
            else
                ignored(end+1,1) = string(fieldName); %#ok<AGROW>
            end
        end

        if ~isempty(ignored)
            warning('optionsGUI:IgnoredLegacyFields', ...
                'Ignoring preset fields not used by the current parameter schema: %s', ...
                strjoin(ignored,', '));
        end

        opts = mergedOpts;
        optsOut = mergedOpts;

        for nReset = 1:N
            reset(nReset);
        end
    end

    function OK(varargin)
        parseAllControls();
        if isgraphics(handles.F)
            delete(handles.F);
        end
    end

    function parseAllControls()
        for k = 1:N
            if isgraphics(handles.ET(k))
                parseET(handles.ET(k),k);
            end
        end
    end

    function reset(n)
        fieldName = optNames{n};
        set(handles.titles(n),'ForegroundColor','k');
        optsOut.(fieldName) = opts.(fieldName);

        if isgraphics(handles.ET(n))
            delete(handles.ET(n));
        end

        [~,xEdit,~,y] = controlPosition(n);
        value = opts.(fieldName);

        switch class(value)
            case 'logical'
                handles.ET(n) = uicontrol( ...
                    'Units','pixels', ...
                    'Parent',handles.F, ...
                    'Style','popupmenu', ...
                    'String',{'false','true'}, ...
                    'Value',double(value)+1, ...
                    'Position',[xEdit y editW rowH], ...
                    'Callback',@(src,evnt) parseET(src,n));

            case 'double'
                handles.ET(n) = uicontrol( ...
                    'Units','pixels', ...
                    'Parent',handles.F, ...
                    'Style','edit', ...
                    'String',num2str(value), ...
                    'Position',[xEdit y editW rowH], ...
                    'Callback',@(src,evnt) parseET(src,n));

            case 'char'
                handles.ET(n) = uicontrol( ...
                    'Units','pixels', ...
                    'Parent',handles.F, ...
                    'Style','edit', ...
                    'String',value, ...
                    'Position',[xEdit y editW rowH], ...
                    'Callback',@(src,evnt) parseET(src,n));

            case 'string'
                handles.ET(n) = uicontrol( ...
                    'Units','pixels', ...
                    'Parent',handles.F, ...
                    'Style','edit', ...
                    'String',char(value), ...
                    'Position',[xEdit y editW rowH], ...
                    'Callback',@(src,evnt) parseET(src,n));

            case 'cell'
                handles.ET(n) = uicontrol( ...
                    'Units','pixels', ...
                    'Parent',handles.F, ...
                    'Style','popupmenu', ...
                    'String',value, ...
                    'Value',1, ...
                    'Position',[xEdit y editW rowH], ...
                    'Callback',@(src,evnt) parseET(src,n));

            otherwise
                error('optionsGUI:UnsupportedParamType', ...
                    'Unsupported parameter type "%s" for option "%s".', ...
                    class(value),fieldName);
        end

        if isfield(tooltips,fieldName)
            set(handles.titles(n),'TooltipString',tooltips.(fieldName));
            set(handles.ET(n),'TooltipString',tooltips.(fieldName));
        end
    end
end

function monitorPos = getTargetMonitor()
%GETTARGETMONITOR Return [x y width height] for the monitor under the mouse.
%
% Using the pointer location works well when MATLAB is moved between local
% and Remote Desktop displays. Fall back to the primary screen if MATLAB
% cannot identify a monitor.

monitorPositions = get(groot,'MonitorPositions');

if isempty(monitorPositions)
    monitorPos = get(groot,'ScreenSize');
    return
end

pointer = get(groot,'PointerLocation');
containsPointer = ...
    pointer(1) >= monitorPositions(:,1) & ...
    pointer(1) <  monitorPositions(:,1)+monitorPositions(:,3) & ...
    pointer(2) >= monitorPositions(:,2) & ...
    pointer(2) <  monitorPositions(:,2)+monitorPositions(:,4);

ix = find(containsPointer,1,'first');
if isempty(ix)
    monitorPos = get(groot,'ScreenSize');
else
    monitorPos = monitorPositions(ix,:);
end
end

function loadedOpts = extractLoadedOptions(loadedFile)
%EXTRACTLOADEDOPTIONS Find a scalar option struct in a saved MAT preset.

if isfield(loadedFile,'optsOut') && isstruct(loadedFile.optsOut)
    loadedOpts = loadedFile.optsOut;
    return
end

if isfield(loadedFile,'params') && isstruct(loadedFile.params)
    loadedOpts = loadedFile.params;
    return
end

names = fieldnames(loadedFile);
isScalarStruct = false(size(names));

for i = 1:numel(names)
    value = loadedFile.(names{i});
    isScalarStruct(i) = isstruct(value) && isscalar(value);
end

ix = find(isScalarStruct);
if numel(ix) == 1
    loadedOpts = loadedFile.(names{ix});
    return
end

error('optionsGUI:InvalidPreset', ...
    ['Preset must contain a scalar struct named "optsOut" or "params", ' ...
     'or exactly one scalar struct variable.']);
end
