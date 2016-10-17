% pRF_auditoryPlugin.m
%
%        $Id:$ 
%      usage: pRF_auditoryPlugin(action,<v>)
%         by: justin gardner
%       date: 11/24/10
%    purpose: Plugin function for pRF directory.
%
function retval = pRF_auditoryPlugin(action,v)

% check arguments
if ~any(nargin == [1 2])
  help pRFPlugin
  return
end

switch action
 case {'install','i'}
  % check for a valid view
  if (nargin ~= 2) || ~isview(v)
     disp(sprintf('(pRF_auditoryPlugin) Need a valid view to install plugin'));
  else
    % if the view is valid, then use mlrAdjustGUI to adjust the GUI for this plugin.
    
    % this installs a new menu item called 'Select Plugins' under /Edit/ROI with the
    % separator turned on above it. It sets the callback to selectPlugins defined below.
    mlrAdjustGUI(v,'add','menu','pRF auditory Analysis','/Analysis/Correlation Analysis','Callback',@callpRF_auditory,'Separator','off');

    % Install default interrogators
    mlrAdjustGUI(v,'add','interrogator',{'pRF_auditoryFit'});

    % This is a command that could be used to install some default colormaps
    % that will show up when you do /Edit/Overlay
    %mlrAdjustGUI(v,'add','colormap','gray');

    % This is a command that could be used to set a property of an existing menu item
    %mlrAdjustGUI(v,'set','Plots/Mean Time Series','Separator','on');

    % return true to indicate successful plugin
    retval = true;
   end
 % return a help string
 case {'help','h','?'}
   retval = 'Runs population receptive field analysis (auditorysensory).';
 otherwise
   disp(sprintf('pRF_auditoryPlugin) Unknown command %s'));
end

end

%%%%%%%%%%%%%%%%%%%%%%%
%    selectPlugins    %
%%%%%%%%%%%%%%%%%%%%%%%
function callpRF_auditory(hObject,eventdata)

% code-snippet to get the view from the hObject variable. Not needed for this callback.
v = viewGet(getfield(guidata(hObject),'viewNum'),'view');
v = pRF_auditory(v);

end


