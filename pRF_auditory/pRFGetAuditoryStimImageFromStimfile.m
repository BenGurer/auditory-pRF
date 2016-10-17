% pRFGetSomatoStimImageFromStimfile
%
%        $Id:$ 
%      usage: stim = pRFGetSomatoStimImageFromStimfile(stimfile,<timePoints>)
%
%         by: ds - based mostly on code by justin gardner
%       date: 2016/02
%    purpose: Pass in a stimfile (can be either a string filename, or a strucutre
%             with myscreen/task) created with mgl / task code 

%             implementation here is based on how information is obtained from 
%             mglRetinotopy stimfile.
%
%             Will
%             create a volume of dimensions x,y,t with the stimulus image (load
%             in mlrVol to view). stim.x and stim.y are the X and Y coordinates
%             (units??). stim.t is the array of times at which image is taken.
%
%             Optionally arguments:
%
%             timePoints: array for which the stim image should be computed. 
%
%             Note for developers - this function needs to keep up-to-date with
%             any changes in the display loop of mglRetinotopy to interpret
%             the stimfiles correctly
%
function stim = pRFGetAuditoryStimImageFromStimfile(stimfile,varargin)

% set default return arguments
stim = [];

% check arguments
if nargin < 1
  help pRFGetSomatoStimImageFromStimfile
  return
end


[d stimNames var] = getStimvol(d,stimVariable,varargin);

stim = d;
