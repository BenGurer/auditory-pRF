% makeDesignMatrix.m
%
%        $Id$
%      usage: makeAuditoryStimImage(d,params,verbose)
%               A modified version of makeDesignMatrix
%         by: farshad moradi, modified by julien besle - made to work with
%         pRF_auditory by Ben Gurer
%       date: 06/14/07, 11/02/2010
%       e.g.: makeDesignMatrix(d,params,verbose)
%    purpose: makes a stimulation convolution matrix
%             for data series. must have getstimtimes already
%             run on it, as well as a model hrf
%              optional parameters can be passed in the params structure 
%
function [stim] = makeAuditoryStimImage(d,params,verbose, scanNum)

if ~any(nargin == [1 2 3 4 5])
   help makeDesignMatrix;
   return
end

if ieNotDefined('params')
  params=struct;
end
if fieldIsNotDefined(params,'scanParams')
  params.scanParams{1}=struct;
  scanNum=1;
end
if ieNotDefined('verbose')
  verbose = 1;
end

if ~fieldIsNotDefined(d,'designSupersampling')
  designSupersampling = d.designSupersampling;
else
  designSupersampling = 1;
end
% if ~fieldIsNotDefined(params.scanParams{scanNum},'acquisitionSubsample')
%   acquisitionSubsample = params.scanParams{scanNum}.acquisitionSubsample;
% else
%   acquisitionSubsample = 1;
% end
if ~fieldIsNotDefined(d,'acquisitionDelay')
  acquisitionDelay = params.acquisitionDelay;
else
  acquisitionDelay = d.tr/2;
end
if isfield(params.scanParams{scanNum},'stimToEVmatrix') && ~isempty(params.scanParams{scanNum}.stimToEVmatrix)
  %match stimNames in params to stimNames in structure d
  [isInMatrix,whichStims] = ismember(d.stimNames,params.scanParams{scanNum}.stimNames);
  stimToEVmatrix = zeros(length(d.stimvol),size(params.scanParams{scanNum}.stimToEVmatrix,2));
  stimToEVmatrix(isInMatrix,:) = params.scanParams{scanNum}.stimToEVmatrix(whichStims(isInMatrix),:);
  if size(stimToEVmatrix,1)~=length(d.stimvol)
    mrWarnDlg('(makeDesignMatrix) EV combination matrix is incompatible with number of event types');
    d.scm = [];
    return;
  end
else
  stimToEVmatrix = eye(length(d.stimvol));
end

% if we have only a single run then we set
% the runTransitions for that single run
if ~isfield(d,'concatInfo') || isempty(d.concatInfo)
  runTransition = [1 d.dim(4)];
else
  runTransition = d.concatInfo.runTransition;
end

numberSamples = diff(runTransition,1,2)+1;
runTransition(:,1) = ((runTransition(:,1)-1)*round(d.designSupersampling)+1);
runTransition(:,2) = runTransition(:,2)*round(d.designSupersampling);

%apply duration and convert to matrix form
stimMatrix = stimCell2Mat(d.stimvol,d.stimDurations,runTransition);
%if design sampling is larger than estimation sampling, we need to correct the amplitude of the hrf 
stimMatrix = stimMatrix*designSupersampling/d.designSupersampling; 

% apply EV combination matrix
d.EVmatrix = stimMatrix*stimToEVmatrix;

% make into pRF image format

 
x = zeros(1, length(d.stimNames));
for k = 1:length(d.stimNames)
    x(:,k) = sscanf(d.stimNames{:,k}, '%*s %d%*s', [1, inf]); % remove text to get frequency in Hz
end
x = x/1000; % convert Hz to kHz
if ~params.Convert2kHz 
    x = funNErb(x);
end    
    
stim = cell(d.concatInfo.n,1); 
for i = 1:d.concatInfo.n
    prune = runTransition(i,:);
    stimMatrixPrune = d.EVmatrix(prune(1):prune(2),:);
    stim{i}.im = permute(stimMatrixPrune,[3,2,1]);
    stim{i}.x = x;
    stim{i}.y = 1;
    stim{i}.t = d.stimfile{i}.mylog.stimtimes_s;
end