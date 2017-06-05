function stim = weightStimImage(d,stim,stimWeightingFunction)

% get weighting function (hearing loss simulation threshold elevating noise)
% create stand alone function from tdtMRI

% get stim image

% get weighting values for each stimulus
% read frequency from stim file
% interp weight function

% normalise weighting values

% replace values in stim image with normalised weighting values
% stim.im
% stim.x
% Get stimulus values in frequency

x = zeros(1, length(d.stimNames));
for k = 1:length(d.stimNames)
    x(:,k) = sscanf(d.stimNames{:,k}, '%*s %d%*s', [1, inf]); % remove text to get frequency in Hz
end
x = x/1000; % convert Hz to kHz
% if ~params.Convert2kHz
%     x = funNErb(x);
% end

% get threshold elevating noise levels at each stimulus frequency
threshEvel = funSimulateHearingLoss(x);
stimLevel = 75;
% normalise by max value
stimWeighting = (stimLevel-threshEvel)/max(threshEvel);

% figure;
% plot(stimWeighting)
% replace each value in stim image with weighted value
% if isfield(d.concatInfo,'n')
% stim = cell(d.concatInfo.n,1); 
for n = 1:d.concatInfo.n
for i = 1:length(stimWeighting)
%     stim{n}.im(:,i,stim{n}.im==1) = 1 - stimWeighting(i);
%     stim{n}.im(find(stim{n}.im(1,i,:)== 1)) = stimWeighting(i);

    stim{n}.im(stim{n}.im(1,i,:)== 1) = stimWeighting(i);
% k = find(stim{n}.im(1,i,:)== 1);
% for ii = 1:length(k)
%     stim{n}.im(1,i,k(ii)) = stimWeighting(i);
% end
end
end
% end