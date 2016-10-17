function stim = getStim(v,scanNum,fitParams)
stimTR = 2
% get stimfile
stimfile = viewGet(v,'stimfile',scanNum);
% get volume to trigger ratio
volTrigRatio = viewGet(v,'auxParam','volTrigRatio',scanNum);
% check if global matches
groupNum = viewGet(v,'curGroup');
global gpRFFitStimImage
if (isfield(fitParams,'recomputeStimImage'))
    disp(sprintf('(pRFFit) Computing stim image'));
%create a volume of dimensions x,y,t with the stimulus image.
% stim.x and stim.y are the X and Y coordinates. stim.t is the array of times at which image is taken.

% stim.x = frequency
% stim.y = 1
% stim.t = time
s = cell(length(stimfile),1); 
for i = 1:length(stimfile)
    s{i} = stimfile{i};
    stimNames = s{i}.stimNames;
    % remove text to get frequency in Hz
    [nRows, nStimuli] = size(stimNames);
    x = zeros(1, nStimuli);
    for k = 1:nStimuli
        x(:,k) = sscanf(stimNames{:,k}, '%*s %d%*s', [1, inf]); % remove text to get frequency in Hz
    end
    x = x/1000; % convert Hz to kHz
    stim{i}.x = x;
    stim{i}.y = 1; % save dimension for future analysis
    stim{i}.t = s{i}.mylog.stimtimes_s
    t = (cell2mat(stim{i}.t))/stimTR;
%     runTimeStart = fitParams.concatInfo.runTransition(i,1);
%     runTimeEnd = fitParams.concatInfo.runTransition(i,2);
    runTime = fitParams.concatInfo.runTransition(i,2) - fitParams.concatInfo.runTransition(i,1) + 1;
    stimMatrix = zeros(runTime,nStimuli);
%     for k = 1:nStimuli
%     stimMatrix(t(i)+runTimeStart-1,i) = 1;
%     end
    for k = 1:nStimuli
    stimMatrix(t(k)+1,k) = 1;
    end
%     stimMatrix = stimCell2Mat(stim{i}.t);
    stim{i}.im = permute(stimMatrix,[3,2,1]);
  
end
% check for averages
  stim = checkStimForAverages(v,scanNum,viewGet(v,'curGroup'),stim,fitParams.concatInfo,fitParams.stimImageDiffTolerance);
  if isempty(stim),return,end
  % make into cell array
  stim = cellArray(stim);
  % save stim image in global
  gpRFFitStimImage.scanNum = scanNum;
  gpRFFitStimImage.groupNum = groupNum;
  gpRFFitStimImage.xFlip = fitParams.xFlipStimulus;
  gpRFFitStimImage.yFlip = fitParams.yFlipStimulus;
  gpRFFitStimImage.timeShift = fitParams.timeShiftStimulus;
  gpRFFitStimImage.stim = stim;
else
  % otherwise load from global
  disp(sprintf('(pRFFit) Using precomputed stim image'));
  stim = gpRFFitStimImage.stim;
end