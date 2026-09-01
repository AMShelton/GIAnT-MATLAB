function optsOut = optionsGUI(opts, tooltips, funcName)

if nargin>2
    caller = funcName;
else
    caller = dbstack;
    if length(caller)>1
        caller = caller(2).name;
    else
        caller = 'Unknown Function';
    end
end

if nargin<2 || isempty(tooltips)
    tooltips = struct();
end

optsOut = opts;

[optNames, sortorder]= sort(fieldnames(opts)); %#ok<FLPST>
N = length(optNames);
titlesX = 5; titlesW = 150;
etX = titlesX+titlesW+20; etW = 115;
H = 15;
H0 =10;
HOK = 40;
handles.F = figure('Name', caller, ...
    'pos', [600 600 titlesW+etW+45 N*(H+H0)+HOK+5], ...
    'toolbar', 'none', 'menubar', 'none', 'resize', 'off', ...
    'numbertitle', 'off');

handles.load = uicontrol(...
    'Units','pixels',...
    'Parent',handles.F,...
    'Style','pushbutton',...
    'Position',[titlesX+60 5 50 20],...
    'String','Load',...
    'Callback', @loadButton);

handles.save = uicontrol(...
    'Units','pixels',...
    'Parent',handles.F,...
    'Style','pushbutton',...
    'Position',[titlesX 5 50 20],...
    'String','Save',...
    'Callback', @saveButton);

handles.OK = uicontrol(...
    'Units','pixels',...
    'Parent',handles.F,...
    'Style','pushbutton',...
    'Position',[etX 5 etW 20],...
    'String','OK',...
    'Callback', @OK);

handles.ET = [];
for n = 1:length(optNames)
    handles.titles(n) = uicontrol(...
        'Units','pixels',...
        'Parent',handles.F,...
        'Style','text',...
        'Position',[titlesX HOK+(n-1)*(H+H0)-4 titlesW H],...
        'String',optNames(n));

    handles.reset(n) = uicontrol(...
        'Units','pixels',...
        'Parent',handles.F,...
        'Style','pushbutton',...
        'Position',[etX+etW+5 HOK+(n-1)*(H+H0)-4 10 H],...
        'String','',...
        'Callback', @(varargin)(reset(n)));

    reset(n);
end
refreshDependencies();
waitfor(handles.F);

    function parseET(src,n)
        type = class(opts.(optNames{n}));
        set(handles.titles(n), 'ForegroundColor', 'k')
        try
            choices = getChoices(n);

            % Choice metadata allows a scalar char/string parameter to render
            % as a popup menu without changing the type of the actual parameter.
            if ~isempty(choices)
                selected = src.String;
                if iscell(selected)
                    selected = selected{src.Value};
                elseif isstring(selected)
                    selected = selected(src.Value);
                end

                if strcmp(type, 'string')
                    optsOut.(optNames{n}) = string(selected);
                else
                    optsOut.(optNames{n}) = char(selected);
                end
                return
            end

            switch type
                case 'logical'
                    optsOut.(optNames{n}) = eval(src.String{src.Value});
                case 'double'
                    optsOut.(optNames{n}) = eval(['[' src.String ']']);
                case 'cell'
                    optsOut.(optNames{n}) = eval(src.String{src.Value});
                case 'char'
                    optsOut.(optNames{n}) = src.String;
                case 'string'
                    optsOut.(optNames{n}) = string(src.String);
            end
        catch
            %make the text error
            set(handles.titles(n), 'ForegroundColor', 'r')
        end
    end

    function parseAndRefresh(src,n)
        parseET(src,n);
        refreshDependencies();
    end

    function saveButton(varargin)
        for k = 1:length(handles.ET)
            parseET(get(handles.ET(k)), k)
        end

        [fn, path] = uiputfile('*.mat');
        if isequal(fn, 0) || isequal(path, 0)
            return
        end
        save(fullfile(path, fn), "optsOut");
    end

    function loadButton(varargin)
        [fn, path] = uigetfile('*.mat');
        if isequal(fn, 0) || isequal(path, 0)
            return
        end

        loaded = load(fullfile(path, fn), "optsOut");
        if ~isfield(loaded, 'optsOut') || ~isstruct(loaded.optsOut)
            error('optionsGUI:InvalidOptionsFile', ...
                'Selected MAT file does not contain a valid optsOut struct.');
        end

        % Merge saved values into current defaults. This is intentionally
        % backwards-compatible with parameter files saved before new fields
        % (such as sourceDetectionMethod) were added.
        loadedOpts = loaded.optsOut;
        for field = fieldnames(loadedOpts)'
            if isfield(opts, field{1})
                opts.(field{1}) = loadedOpts.(field{1});
            end
        end
        optsOut = opts;

        for n = 1:length(optNames)
            reset(n);
        end
        refreshDependencies();
    end

    function OK(varargin)
        for k = 1:length(handles.ET)
            parseET(get(handles.ET(k)), k)
        end
        delete(handles.F)
    end

    function reset(n)
        set(handles.titles(n), 'ForegroundColor', 'k')
        optsOut.(optNames{n}) = opts.(optNames{n});

        if length(handles.ET)>=n && isgraphics(handles.ET(n))
            delete(handles.ET(n));
        end

        choices = getChoices(n);
        if ~isempty(choices)
            currentValue = opts.(optNames{n});
            if isstring(currentValue)
                currentValue = char(currentValue);
            end
            selectedIx = find(strcmp(choices, currentValue), 1, 'first');
            if isempty(selectedIx)
                selectedIx = 1;
                optsOut.(optNames{n}) = choices{1};
            end

            handles.ET(n) = uicontrol(...
                'Units','pixels',...
                'Parent',handles.F,...
                'Style','popupmenu',...
                'String', choices,...
                'Value', selectedIx,...
                'Position',[etX HOK+(n-1)*(H+H0) etW H],...
                'callback', @(src,evnt)(parseAndRefresh(src, n)));
        else
            switch class(opts.(optNames{n}))
                case 'logical' %make a drop down menu
                    handles.ET(n) = uicontrol(...
                        'Units','pixels',...
                        'Parent',handles.F,...
                        'Style','popupmenu',...
                        'String', {'false', 'true'},...
                        'Value', double(opts.(optNames{n}))+1,...
                        'Position',[etX HOK+(n-1)*(H+H0) etW H],...
                        'callback', @(src,evnt)(parseAndRefresh(src, n)));

                case 'double'
                    handles.ET(n) = uicontrol(...
                        'Units','pixels',...
                        'Parent',handles.F,...
                        'Style','edit',...
                        'String', num2str(opts.(optNames{n})),...
                        'Position',[etX HOK+(n-1)*(H+H0)-4 etW H],...
                        'callback', @(src,evnt)(parseAndRefresh(src, n)));

                case 'char'
                    handles.ET(n) = uicontrol(...
                        'Units','pixels',...
                        'Parent',handles.F,...
                        'Style','edit',...
                        'String', opts.(optNames{n}),...
                        'Position',[etX HOK+(n-1)*(H+H0)-4 etW H],...
                        'callback', @(src,evnt)(parseAndRefresh(src, n)));

                case 'string'
                    handles.ET(n) = uicontrol(...
                        'Units','pixels',...
                        'Parent',handles.F,...
                        'Style','edit',...
                        'String', opts.(optNames{n}),...
                        'Position',[etX HOK+(n-1)*(H+H0)-4 etW H],...
                        'callback', @(src,evnt)(parseAndRefresh(src, n)));

                case 'cell' %make a drop down
                    handles.ET(n) = uicontrol(...
                        'Units','pixels',...
                        'Parent',handles.F,...
                        'Style','popupmenu',...
                        'String', opts.(optNames{n}),...
                        'Value', 1,...
                        'Position',[etX HOK+(n-1)*(H+H0) etW H],...
                        'callback', @(src,evnt)(parseAndRefresh(src, n)));

                otherwise
                    error('optionsGUI:UnsupportedParamType', ...
                        'Unsupported parameter type "%s" for option "%s".', ...
                        class(opts.(optNames{n})), optNames{n});
            end
        end

        if isstruct(tooltips) && isfield(tooltips, optNames{n})
            set(handles.titles(n), 'TooltipString', tooltips.(optNames{n}));
            set(handles.ET(n), 'TooltipString', tooltips.(optNames{n}));
        end
    end

    function choices = getChoices(n)
        choices = {};
        if ~isstruct(tooltips) || ~isfield(tooltips, '__choices') || ...
                ~isstruct(tooltips.choiceLists)
            return
        end

        fieldName = optNames{n};
        if ~isfield(tooltips.choiceLists, fieldName)
            return
        end

        choices = tooltips.choiceLists.(fieldName);
        if isstring(choices)
            choices = cellstr(choices);
        elseif ischar(choices)
            choices = {choices};
        end

        if ~iscellstr(choices) %#ok<ISCLSTR>
            error('optionsGUI:InvalidChoiceMetadata', ...
                'Choice list for "%s" must be a cell array of character vectors or a string array.', ...
                fieldName);
        end
    end

    function refreshDependencies()
        % SILo-specific UX: maxSynapseDensity is only relevant to the
        % summarize_LoCo backend. This affects the GUI only; setParams performs
        % the authoritative validation before returning parameters.
        methodIx = find(strcmp(optNames, 'sourceDetectionMethod'), 1);
        densityIx = find(strcmp(optNames, 'maxSynapseDensity'), 1);

        if isempty(methodIx) || isempty(densityIx) || ...
                length(handles.ET) < max(methodIx, densityIx) || ...
                ~isgraphics(handles.ET(methodIx)) || ...
                ~isgraphics(handles.ET(densityIx))
            return
        end

        method = optsOut.sourceDetectionMethod;
        if isstring(method)
            method = char(method);
        end

        isLoCo = ischar(method) && strcmpi(strtrim(method), 'summarize_loco');
        if isLoCo
            set(handles.ET(densityIx), 'Enable', 'on');
            set(handles.titles(densityIx), 'ForegroundColor', 'k');
        else
            set(handles.ET(densityIx), 'Enable', 'off');
            set(handles.titles(densityIx), 'ForegroundColor', [0.5 0.5 0.5]);
        end
    end
end
