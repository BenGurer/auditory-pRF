
function stim = dynamicRangeOfStimulus(stim,stimInfo,d,weightingType,params,compression)

% use a drop down menu to choose weighting type
% use tick box to fit mod
if isfield(d.concatInfo,'n')
    x = stim{1}.x;
else
    x = stim.x;
end

stimulusLevel_dbSPL = 75;
maskingLevel_dbSPL = 25;
threshold_sHL_dBSLP = funSimulateHearingLoss(funInvNErb(x));
masking_Baseline = maskingLevel_dbSPL*ones(size(x));
masking_dbSPL =  max(threshold_sHL_dBSLP,masking_Baseline);
stimulusLevel_dbSL = stimulusLevel_dbSPL-masking_dbSPL;

switch weightingType
    case 'SL_level'
               
        % %     Convert to pressure
        % %   Lp(dB SPL) = 20 log10 p/p0
        % %   p0 = 0.00002 pa
        % %   p(Pa) = p0 .10.^ Lp(dB SPL)/20
        % stimWeightingPressure = 0.00002 .* 10.^(stimulusLevel_dbSL/20);
        % %       stimWeightingIntensity = 10.^-12 .* 10.^((20 .* log10(stimWeightingPressure/10.^-5))/10);
        % stimWeightingIntensity = (stimWeightingPressure.^2) / 400;
        % stimulusLevel_dbSL = stimWeightingIntensity;
        % %     stimWeighting = 10.^(stimWeighting/10);
        % stimulusLevel_dbSL = stimulusLevel_dbSL/max(stimulusLevel_dbSL);
        % %     stimWeighting = (stimLevel-threshEvel)/stimSLlevel;
        
        % % normalise by max value
        stimulusWeighting = (stimulusLevel_dbSL)/max(stimulusLevel_dbSL);
        
    case 'BOLD'
        %         R = m.SL + b;
        m = params.SWgradient;
        b = params.SWoffset;
%         m = 0.0174;
%         b = -0.1176;
        R = @(SL) m.*SL + b;
        stimulusWeighting = R(stimulusLevel_dbSL);
        
    case 'fit'
        
        stimulusWeighting = (stimulusLevel_dbSL)/max(stimulusLevel_dbSL);
        stimulusWeighting = stimulusWeighting.^compression;        
end

%     alpha = 0.5; % apply compressive or expansive function - is brain activity linearally related to dB level
%     stimWeighting = stimWeighting.^alpha;



if isfield(d.concatInfo,'n')
    for i = 1:d.concatInfo.n
        stimulusWeighting_rep = repmat(stimulusWeighting,1,1,length(stim{i}.im));
        stim{i}.im = stimulusWeighting_rep .* stim{i}.im;
        
    end
else
    
    stimulusWeighting_rep = repmat(stimulusWeighting,1,1,length(stim.im));
    stim.im = stimulusWeighting_rep .* stim.im;
    
end