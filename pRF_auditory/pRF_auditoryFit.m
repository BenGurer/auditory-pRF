% pR_auditoryFit
%
%      usage: pRF_auditoryFit(v,scanNum,x,y,s,<dispFit=0>)
%         by: Ben Gurer / completely base on code by justin gardner and
%         Denis Schluppeck
%       date: Oct-2016 [ds 201602 [orig 11/14/2011]]
%    purpose: interrogator that fits pRF model to selected voxel

%% to do
%
% line 841 % change prefit values to be based on stimulus properties
% line 261 % set search limits by menu or stimulus type - ie auditory etc

function fit = pRF_auditoryFit(varargin)

fit = [];
% parse input arguments - note that this is set
% up so that it can also be called as an interrogator
[v scanNum x y z fitParams tSeries] = parseArgs(varargin);
if isempty(v),return,end
 
% get concat info
if ~isfield(fitParams,'concatInfo') || isempty(fitParams.concatInfo)
  fitParams.concatInfo = viewGet(v,'concatInfo',scanNum);
end

% if there is no concatInfo, then make one that will
% treat the scan as a single scan
if isempty(fitParams.concatInfo)
  nFrames = viewGet(v,'nFrames',scanNum);
  fitParams.concatInfo.isConcat = false;
  fitParams.concatInfo.n = 1;
  fitParams.concatInfo.whichScan = ones(1,nFrames);
  fitParams.concatInfo.whichVolume = 1:nFrames;
  fitParams.concatInfo.runTransition = [1 nFrames];
  fitParams.concatInfo.totalJunkedFrames = viewGet(v,'totalJunkedFrames',scanNum);
  if length(fitParams.concatInfo.totalJunkedFrames > 1)
    % first check for consistency in totalJunkedFrames
    if length(unique(fitParams.concatInfo.totalJunkedFrames)) > 1
      disp(sprintf('(pRFFit) totalJunkedFrames are different for different members of component scans - could be an average in which different scans with different number of junked frames were removed. This could cause a problem in computing what the stimulus was for the average. The total junked frames count was: %s, but we will use %i as the actual value for computing the stimulus',num2str(fitParams.concatInfo.totalJunkedFrames),floor(median(fitParams.concatInfo.totalJunkedFrames))));
    end
    fitParams.concatInfo.totalJunkedFrames = floor(median(fitParams.concatInfo.totalJunkedFrames));
  end
else
  fitParams.concatInfo.isConcat = true;
  if ~isfield(fitParams.concatInfo,'totalJunkedFrames')
    fitParams.concatInfo.totalJunkedFrames = viewGet(v,'totalJunkedFrames',scanNum);
  end
end

% get the stimulus movie if it wasn't passed in
if ~isfield(fitParams,'stim') || isempty(fitParams.stim)
  fitParams.stim = getStim(v,scanNum,fitParams);
end
if isempty(fitParams.stim),return,end

% if we are being called to just return the stim image 
% then return it here
if fitParams.justGetStimImage
  fit = fitParams.stim;
  return
end

if isempty(fitParams.prefit) || (fitParams.prefit.quickPrefit ~= fitParams.quickPrefit)
    % set the values over which to first prefit
    % the best of these parameters will then be used
    % to init the non-linear optimization. Note that the
    % values here are expressed as a factor of the screen
    % dimensions (1 being the width/height of the screen)
    % Later when the prefit is calculated, they will be multiplied
    % by the screenWidth and screenHeight  
fitParams = getPrefit(fitParams);
end

% get the tSeries
if ~isempty(x)
  % if tSeries was not passed in then load it
  if isempty(tSeries)
    % load using loadTSeries
    tSeries = squeeze(loadTSeries(v,scanNum,z,[],x,y));
  end

  % convert to percent tSeries. Note that we  detrend here which is not necessary for concats,
  % but useful for raw/motionCorrected time series. Also, it is very important that
  % the tSeries is properly mean subtracted
  if ~isfield(fitParams.concatInfo,'hipassfilter')
    tSeries = percentTSeries(tSeries,'detrend','Linear','spatialNormalization','Divide by mean','subtractMean', 'Yes', 'temporalNormalization', 'No');
  end
  
  % if there are any nans in the tSeries then don't fit
  if any(isnan(tSeries))
    if fitParams.verbose
      disp(sprintf('(pRF_auditoryFit) Nan found in tSeries for voxel [%i %i %i] in scan %s:%i. Abandoning fit',x,y,z,viewGet(v,'groupName'),scanNum));
    end
    fit=[];return
  end
else
  tSeries = [];
end

% handle junk frames (i.e. ones that have not already been junked)
if ~isempty(fitParams.junkFrames) && ~isequal(fitParams.junkFrames,0)
  % drop junk frames
  disp(sprintf('(pRF_auditoryFit) Dropping %i junk frames',fitParams.junkFrames));
  tSeries = tSeries(fitParams.junkFrames+1:end);
  if ~isfield(fitParams.concatInfo,'totalJunkedFramesIncludesJunked');
    fitParams.concatInfo.totalJunkedFrames = fitParams.concatInfo.totalJunkedFrames+fitParams.junkFrames;
    fitParams.concatInfo.totalJunkedFramesIncludesJunked = 1;
  end
end


% set up the fit routine params
fitParams = setFitParams(fitParams);

% just return model response for already calcualted params
if fitParams.getModelResponse
  % get model fit
  [residual fit.modelResponse fit.rfModel r scale] = getModelResidual(fitParams.params,tSeries,fitParams);
  % get the canonical
  fit.p = getFitParams(fitParams.params,fitParams);
  fit.canonical = getCanonicalHRF(fit.p.canonical,fitParams.framePeriod);
  % return tSeries
  fit.tSeries = tSeries;
  return;
end

% return some fields
fit.stim = fitParams.stim;
fit.stimX = fitParams.stimX;
fit.stimY = fitParams.stimY;
fit.stimT = fitParams.stimT;
fit.concatInfo = fitParams.concatInfo;
fit.nParams = fitParams.nParams;
paramsInfoFields = {'minParams','maxParams','initParams','paramNames','paramDescriptions'};
for iField = 1:length(paramsInfoFields)
  fit.paramsInfo.(paramsInfoFields{iField}) = fitParams.(paramsInfoFields{iField});
end
% test to see if scan lengths and stim lengths match
% tf = true;
% for iScan = 1:fit.concatInfo.n
%   sLength = fit.concatInfo.runTransition(iScan,2) - fit.concatInfo.runTransition(iScan,1) + 1;
%   if sLength ~= size(fitParams.stim{iScan}.im,3)
%     mrWarnDlg(sprintf('(pRF_auditoryFit) Data length of %i for scan %i (concatNum:%i) does not match stimfile length %i',fit.concatInfo.runTransition(iScan,2),scanNum,iScan,size(fitParams.stim{iScan}.im,3)));
%     tf = false;
%   end
% end
% 
% if ~tf,fit = [];return,end

% do prefit. This computes (or is passed in precomputed) model responses
% for a variety of parameters and calculates the correlation between
% the models and the time series. The one that has the best correlation
% is then used as the initial parameters for the nonlinear fit. This
% helps prevent getting stuck in local minima
if isfield(fitParams,'prefit') && ~isempty(fitParams.prefit)
  params = fitParams.initParams;
  % calculate model if not already calculated
  if ~isfield(fitParams.prefit,'modelResponse')
    % get number of workers
    nProcessors = mlrNumWorkers;
    disppercent(-inf,sprintf('(pRF_auditoryFit) Computing %i prefit model responses using %i processors',fitParams.prefit.n,nProcessors));
    % first convert the x/y and width parameters into sizes
    % on the actual screen
    fitParams.prefit.x = fitParams.prefit.x*fitParams.stimWidth;
    fitParams.prefit.y = fitParams.prefit.y*fitParams.stimHeight;
    fitParams.prefit.rfHalfWidth = fitParams.prefit.rfHalfWidth*max(fitParams.stimWidth,fitParams.stimHeight);
    % init modelResponse
    allModelResponse = nan(fitParams.prefit.n,fitParams.concatInfo.runTransition(end,end));
    % compute all the model response, using parfor loop
    % parfor i = 1:fitParams.prefit.n
    
    % save fitParams for external use
    fit.fitParams = fitParams;
    
    for i = 1:fitParams.prefit.n
        % fit the model with these parameters
        if fitParams.fitHDR
            [residual modelResponse rfModel r scale] = getModelResidual([fitParams.prefit.x(i) fitParams.prefit.y(i) fitParams.prefit.rfHalfWidth(i) fitParams.prefit.HDRExp(i) params(5:end)],tSeries,fitParams,1);
        else
            [residual modelResponse rfModel r scale] = getModelResidual([fitParams.prefit.x(i) fitParams.prefit.y(i) fitParams.prefit.rfHalfWidth(i) params(4:end)],tSeries,fitParams,1);
        end
      % normalize to 0 mean unit length
      allModelResponse(i,:) = (modelResponse-mean(modelResponse))./sqrt(sum(modelResponse.^2))';
      if fitParams.verbose
	disp(sprintf('(pRF_auditoryFit) Computing prefit model response %i/%i: Center [%6.2f,%6.2f] rfHalfWidth=%5.2f HDRExp=%5.2f',i,fitParams.prefit.n,fitParams.prefit.x(i),fitParams.prefit.y(i),fitParams.prefit.rfHalfWidth(i),fitParams.prefit.HDRExp(i)));
      end
    end
    disppercent(inf);
    fitParams.prefit.modelResponse = allModelResponse;
    clear allModelResponse;
  end
  % save in global, so that when called as an interrogator
  % we don't have to keep computing fitParams
  global gpRFFitTypeParams
  gpRFFitTypeParams.prefit = fitParams.prefit;
  % return some computed fields
  fit.prefit = fitParams.prefit;
  if fitParams.returnPrefit,return,end
  % normalize tSeries to 0 mean unit length
  tSeriesNorm = (tSeries-mean(tSeries))/sqrt(sum(tSeries.^2));
  % calculate r for all modelResponse by taking inner product
  r = fitParams.prefit.modelResponse*tSeriesNorm;
  % get best r2 for all the models
  [maxr bestModel] = max(r);
  fitParams.initParams(1) = fitParams.prefit.x(bestModel);
  fitParams.initParams(2) = fitParams.prefit.y(bestModel);
  fitParams.initParams(3) = fitParams.prefit.rfHalfWidth(bestModel);
  if fitParams.fitHDR
  fitParams.initParams(4) = fitParams.prefit.HDRExp(bestModel);
  end
  if fitParams.prefitOnly
    % return if we are just doing a prefit
    fit = getFitParams(fitParams.initParams,fitParams);
    fit.rfType = fitParams.rfType;
    fit.params = fitParams.initParams;
    fit.r2 = maxr^2;
    fit.r = maxr;
    % [fit.polarAngle fit.eccentricity] = cart2pol(fit.x,fit.y);
    fit.PrefCentreFreq = fit.x;
    fit.PrefY = fit.y;
    fit.rfHalfWidth = fit.std;
       
    % display
    if fitParams.verbose
      % disp(sprintf('%s[%2.f %2.f %2.f] r2=%0.2f polarAngle=%6.1f eccentricity=%6.1f rfHalfWidth=%6.1f',fitParams.dispstr,x,y,z,fit.r2,r2d(fit.polarAngle),fit.eccentricity,fit.std));
      disp(sprintf('%s[%2.f %2.f %2.f] r2=%0.2f PrefCentreFreq=%6.1f PrefY=%6.1f rfHalfWidth=%6.1f',fitParams.dispstr,x,y,z,fit.r2,fit.PrefCentreFreq,fit.PrefY,fit.std));
    
    end
    return
  end
end

% now do nonlinear fit
if strcmp(lower(fitParams.algorithm),'levenberg-marquardt')
  [params resnorm residual exitflag output lambda jacobian] = lsqnonlin(@getModelResidual,fitParams.initParams,fitParams.minParams,fitParams.maxParams,fitParams.optimParams,tSeries,fitParams);
elseif strcmp(lower(fitParams.algorithm),'nelder-mead')
  [params fval exitflag] = fminsearch(@getModelResidual,fitParams.initParams,fitParams.optimParams,(tSeries-mean(tSeries))/var(tSeries.^2),fitParams);
else
  disp(sprintf('(pRF_auditoryFit) Unknown optimization algorithm: %s',fitParams.algorithm));
  return
end

% set output arguments
fit = getFitParams(params,fitParams);
fit.rfType = fitParams.rfType;
fit.params = params;

% compute r^2
[residual modelResponse rfModel fit.r scale] = getModelResidual(params,tSeries,fitParams);
if strcmp(lower(fitParams.algorithm),'levenberg-marquardt')
  fit.r2 = 1-sum((residual-mean(residual)).^2)/sum((tSeries-mean(tSeries)).^2);
elseif strcmp(lower(fitParams.algorithm),'nelder-mead')
  fit.r2 = residual^2;
end

%% AIC
% These are the formulas for the AIC and AICc (which is corrected for the number of parameters in the model)
% error = residual;
% N = length(residual);
% nParams = fitParams.nParams; %nParams is the number of parameters in the model N is the number of datapoints error is the N-vector of differences between the modelle and actual data
% % aic = 2*nParams + N*(log(2*pi) + 1 - log(N) + log(sum(sum(error.^2))));
% % aicc = aic + 2*nParams*(nParams+1)/(N-nParams-1);
% % fit.aic = 2*nParams + N*(log(2*pi) + 1 - log(N) + log(sum(sum(error.^2))));
% l =  0.5*(-nParams*(log(2*pi) +1 - log(nParams) + log(sum(error.^2))));
% fit.aic = 2*nParams - 2*l;
% fit.aicc = fit.aic + 2*nParams*(nParams+1)/(N-nParams-1);

%% Root-mean-square deviation
fit.RMSD = (sum(residual.^2))/fitParams.nParams;
fit.NRMSD = fit.RMSD/max(residual)-min(residual);


% save population receptive field properties
% can convert values to other scales if not fitted in the desired scaling
% [fit.polarAngle fit.eccentricity] = cart2pol(fit.x,fit.y);
fit.PrefCentreFreq = fit.x;
% fit.PrefY = fit.y;
fit.rfHalfWidth = fit.std;
fit.hdrExp = fit.canonical.exponent;
% fit.hdrtimelag = fit.canonical.timelag;
% fit.hdr = fit.canonical;
% fit.scale = scale;
% fit.N = N;

if any(strcmp(fitParams.voxelScale,{'lin'}))
   fit.pCFscaled = funInvNErb(fit.x); 
elseif any(strcmp(fitParams.voxelScale,{'log'}))
fit.pCFscaled = log10(fit.x);
elseif any(strcmp(fitParams.voxelScale,{'erb'}))
fit.pCFscaled = funNErb(fit.x);
else
  disp(sprintf('(pRFFit) Unknown voxelScale: %s',fitParams.voxelScale));
end

% display
if fitParams.verbose
  % disp(sprintf('%s[%2.f %2.f %2.f] r2=%0.2f polarAngle=%6.1f eccentricity=%6.1f rfHalfWidth=%6.1f',fitParams.dispstr,x,y,z,fit.r2,r2d(fit.polarAngle),fit.eccentricity,fit.std));
  disp(sprintf('%s[%2.f %2.f %2.f] r2=%1.2f pCF=%1.3f rTW=%1.3f HDRexp=%1.2f NRMSD=%1.2f',fitParams.dispstr,x,y,z,fit.r2,fit.PrefCentreFreq,fit.std,fit.hdrExp,fit.NRMSD));
    
end

%%%%%%%%%%%%%%%%%%%%%%
%    setFitParams    %
%%%%%%%%%%%%%%%%%%%%%%
function fitParams = setFitParams(fitParams)

% set rfType
if ~isfield(fitParams,'rfType') || isempty(fitParams.rfType)
  fitParams.rfType = 'gaussian';
end

% get stimulus x,y and t
fitParams.stimX = fitParams.stim{1}.x;
fitParams.stimY = fitParams.stim{1}.y;
fitParams.stimT = fitParams.stim{1}.t;

% this could be modified to be ERB : it would be different value for each
% condition
fitParams.stimWidth = 1;  % fitParams.stimExtents(3)-fitParams.stimExtents(1);
fitParams.stimHeight = 1; % fitParams.stimExtents(4)-fitParams.stimExtents(2);

StimXMin = min(fitParams.stimX)*0.5;
StimXMax = max(fitParams.stimX)*2;


if ~isfield(fitParams,'initParams')
    
    % parameter names/descriptions and other information for allowing user to set them
    fitParams.paramNames = {'x','y','rfWidth'};
    fitParams.paramDescriptions = {'RF x position (Frequency)','RF y position (Unused)','RF width (std of gaussian)'};
    fitParams.paramIncDec = [0.01 1 0.1];
    fitParams.paramMin = [StimXMin -1 0.001];
    fitParams.paramMax = [StimXMax 1.1 inf];
    % set min/max and init
    fitParams.minParams = [StimXMin 1 0.001];
    fitParams.maxParams = [StimXMax 1.1 inf];
    fitParams.initParams = [0 0 4];
    if fitParams.fitHDR     
        fitParams.paramNames = {fitParams.paramNames{:} 'exp','timelag','tau'};
        fitParams.paramDescriptions = {fitParams.paramDescriptions{:} 'Exponent','Time before start of rise of hemodynamic function','Width of the hemodynamic function (tau parameter of gamma)'};
        fitParams.paramIncDec = [fitParams.paramIncDec(:)' 0.5 0.1 0.1];
        fitParams.paramMin = [fitParams.paramMin(:)' 0 0 0];
        fitParams.paramMax = [fitParams.paramMax(:)' 16 16 inf];
        % set min/max and init
        fitParams.minParams = [fitParams.minParams 0 0 0];
        fitParams.maxParams = [fitParams.maxParams 16 3 inf];
        fitParams.initParams = [fitParams.initParams fitParams.exponent fitParams.timelag fitParams.tau];
        
        % add on parameters for difference of gamma
        if fitParams.diffOfGamma
            % parameter names/descriptions and other information for allowing user to set them
            fitParams.paramNames = {fitParams.paramNames{:} 'exp2' 'amp2' 'timelag2','tau2'};
            fitParams.paramDescriptions = {fitParams.paramDescriptions{:} 'Exponent2' 'Amplitude of second gamma for HDR' 'Timelag for second gamma for HDR','tau for second gamma for HDR'};
            fitParams.paramIncDec = [fitParams.paramIncDec(:)'  0.5 0.1 0.1 0.1];
            fitParams.paramMin = [fitParams.paramMin(:)' 0 0 0 0];
            fitParams.paramMax = [fitParams.paramMax(:)' 16 inf 16 inf];
            % set min/max and init
            fitParams.minParams = [fitParams.minParams 0 0 0 0];
            fitParams.maxParams = [fitParams.maxParams 16 inf 16 inf];
            fitParams.initParams = [fitParams.initParams fitParams.exponent2 fitParams.amplitudeRatio fitParams.timelag2 fitParams.tau2];
        end
    end  

  
  % round constraints
  fitParams.minParams = round(fitParams.minParams*10)/10;
  fitParams.maxParams = round(fitParams.maxParams*10)/10;

  % handle constraints here
  % Check if fit algorithm is one that allows constraints
  algorithmsWithConstraints = {'levenberg-marquardt'};
  if any(strcmp(fitParams.algorithm,algorithmsWithConstraints))
    % if constraints allowed then allow user to adjust them here (if they set defaultConstraints)
    if isfield(fitParams,'defaultConstraints') && ~fitParams.defaultConstraints
      % create a dialog to allow user to set constraints
      paramsInfo = {};
      for iParam = 1:length(fitParams.paramNames)
	paramsInfo{end+1} = {sprintf('min%s',fitParams.paramNames{iParam}) fitParams.minParams(iParam) sprintf('Minimum for parameter %s (%s)',fitParams.paramNames{iParam},fitParams.paramDescriptions{iParam}) sprintf('incdec=[%f %f]',-fitParams.paramIncDec(iParam),fitParams.paramIncDec(iParam)) sprintf('minmax=[%f %f]',fitParams.paramMin(iParam),fitParams.paramMax(iParam))};
	paramsInfo{end+1} = {sprintf('max%s',fitParams.paramNames{iParam}) fitParams.maxParams(iParam) sprintf('Maximum for parameter %s (%s)',fitParams.paramNames{iParam},fitParams.paramDescriptions{iParam})  sprintf('incdec=[%f %f]',-fitParams.paramIncDec(iParam),fitParams.paramIncDec(iParam)) sprintf('minmax=[%f %f]',fitParams.paramMin(iParam),fitParams.paramMax(iParam))};
      end
      params = mrParamsDialog(paramsInfo,'Set parameter constraints');
      % if params is not empty then set them
      if isempty(params)
	disp(sprintf('(pRFFit) Using default constraints'));
      else
	% get the parameter constraints back from the dialog entries
	for iParam = 1:length(fitParams.paramNames)
	  fitParams.minParams(iParam) = params.(sprintf('min%s',fitParams.paramNames{iParam}));
	  fitParams.maxParams(iParam) = params.(sprintf('max%s',fitParams.paramNames{iParam}));
	end
      end
    end
    % Now display parameter constraints
    for iParam = 1:length(fitParams.paramNames)
      disp(sprintf('(pRFFit) Parameter %s [min:%f max:%f] (%i:%s)',fitParams.paramNames{iParam},fitParams.minParams(iParam),fitParams.maxParams(iParam),iParam,fitParams.paramDescriptions{iParam}));
    end
  else
    % no constraints allowed
    disp(sprintf('(pRF_auditoryFit) !!! Fit constraints ignored for algorithm: %s (if you want to constrain the fits, then use: %s) !!!',fitParams.algorithm,cell2mat(algorithmsWithConstraints)));
  end
end

fitParams.nParams = length(fitParams.initParams);

% optimization parameters
if ~isfield(fitParams,'algorithm') || isempty(fitParams.algorithm)
  fitParams.algorithm = 'nelder-mead';
end
fitParams.optimParams = optimset('MaxIter',inf,'Display',fitParams.optimDisplay);

% compute number of frames
fitParams.nFrames = size(fitParams.stim{1}.im,3);

% parameters for converting the stimulus
params = {'xFlip','yFlip','timeShiftStimulus'};
for i = 1:length(params)
  if ~isfield(fitParams,params{i}) || isempty(fitParams.(params{i}))
    fitParams.(params{i}) = 0;
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   getModelResidual   %%
%%%%%%%%%%%%%%%%%%%%%%%%%%
function [residual modelResponse rfModel r scale] = getModelResidual(params,tSeries,fitParams,justGetModel)

residual = [];
r = [];
scale = [];

if nargin < 4, justGetModel = 0;end

if ~fieldIsNotDefined(fitParams.d,'designSupersampling')
  designSupersampling = fitParams.d.designSupersampling;
else
  designSupersampling = 1;
end

if ~fieldIsNotDefined(fitParams,'acquisitionDelay')
  acquisitionDelay = fitParams.acquisitionDelay;
else
  acquisitionDelay = fitParams.d.tr/2;
end

% get the model response
% convert parameter array into a parameter strucutre
p = getFitParams(params,fitParams);

% compute an RF
rfModel = getRFModel(p,fitParams);
% % % include auditory model here:
% rfModel = getauditoryRFModel(p, fitParams);


% init model response
modelResponse = [];residual = [];

% create the model for each concat
for i = 1:fitParams.concatInfo.n
  % get model response
  thisModelResponse = convolveModelWithStimulus(rfModel,fitParams.stim{i});

  % get a model hrf
  hrf = getCanonicalHRF(p.canonical,fitParams.framePeriod);

  % and convolve in time.
  thisModelResponse = convolveModelResponseWithHRF(thisModelResponse,hrf);
  
  % drop junk frames here
  thisModelResponse = thisModelResponse(fitParams.concatInfo.totalJunkedFrames(i)+1:end);
  if ~fieldIsNotDefined(fitParams.d,'designSupersampling')
      %   thisModelResponse = pRF_resampleDesignMatrix(thisModelResponse,params,fitParams);
      sampleNumber = floor(rem(acquisitionDelay,fitParams.d.tr)*designSupersampling/fitParams.d.tr)+1;
      thisModelResponse = mrDownsample(thisModelResponse, designSupersampling, sampleNumber);
  end
  
  % apply concat filtering
  if isfield(fitParams,'applyFiltering') && fitParams.applyFiltering
      thisModelResponse = applyConcatFiltering(thisModelResponse,fitParams.concatInfo,i);
  else
    % with no filtering, just remove mean
    thisModelResponse = thisModelResponse - mean(thisModelResponse);
  end
   
  if ~justGetModel
    % compute correlation of this portion of the model response with time series
    thisTSeries = tSeries(fitParams.concatInfo.runTransition(i,1):fitParams.concatInfo.runTransition(i,2));
    thisTSeries = thisTSeries - mean(thisTSeries);
    
    % check here for length
    if length(thisTSeries) ~= length(thisModelResponse)
      disp(sprintf('(pRFFit:getModelResidual) Voxel tSeries length of %i does not match model length of %i. This can happen, for instance, if the tSense factor was not set correctly or junk frames was not set correctly.',length(thisTSeries),length(thisModelResponse)));
      keyboard
    end
  
    r(i) = corr(thisTSeries(:),thisModelResponse(:));

    if fitParams.betaEachScan
      % scale and offset the model to best match the tSeries
      [thisModelResponse thisResidual scale] = scaleAndOffset(thisModelResponse',thisTSeries(:));
    else
      thisResidual = [];
    end
  else
    thisResidual = [];
    
  end
    % make into a column array
  modelResponse = [modelResponse;thisModelResponse(:)];
  residual = [residual;thisResidual(:)];
end

% return model only
if justGetModel,return,end

% scale the whole time series
if ~fitParams.betaEachScan
  [modelResponse residual scale] = scaleAndOffset(modelResponse,tSeries(:));
end


% display the fit
if fitParams.dispFit
  dispModelFit(params,fitParams,modelResponse,tSeries,rfModel);
end

% for nelder-mead just compute correlation and return 1-4
if strcmp(lower(fitParams.algorithm),'nelder-mead')
  residual = -corr(modelResponse,tSeries);
%  disp(sprintf('(pRFFit:getModelResidual) r: %f',residual));
end


%%%%%%%%%%%%%%%%%%%%%%
%    dispModelFit    %
%%%%%%%%%%%%%%%%%%%%%%
function dispModelFit(params,fitParams,modelResponse,tSeries,rfModel)

mlrSmartfig('pRFFit_getModelResidual','reuse');
clf
subplot(4,4,[1:3 5:7 9:11 13:15]);
%plot(fitParams.stimT(fitParams.junkFrames+1:end),tSeries,'k-');
plot(tSeries,'k-');
hold on
%plot(fitParams.stimT(fitParams.junkFrames+1:end),modelResponse,'r-');
plot(modelResponse,'r-');
xlabel('Time (sec)');
ylabel('BOLD (% sig change)');
p = getFitParams(params,fitParams);
titleStr = sprintf('x: %s y: %s rfHalfWidth: %s',mlrnum2str(p.x),mlrnum2str(p.y),mlrnum2str(p.std));
titleStr = sprintf('%s\n(timelag: %s tau: %s exponent: %s)',titleStr,mlrnum2str(p.canonical.timelag),mlrnum2str(p.canonical.tau),mlrnum2str(p.canonical.exponent));
if p.canonical.diffOfGamma
  titleStr = sprintf('%s - %s x (timelag2: %s tau2: %s exponent2: %s)',titleStr,mlrnum2str(p.canonical.amplitudeRatio),mlrnum2str(p.canonical.timelag2),mlrnum2str(p.canonical.tau2),mlrnum2str(p.canonical.exponent2));
end
title(titleStr);
axis tight

subplot(4,4,[8 12 16]);
imagesc(fitParams.stimX(:,1),fitParams.stimY(1,:),flipud(rfModel'));
axis image;
hold on
hline(0);vline(0);

subplot(4,4,4);cla
p = getFitParams(params,fitParams);
canonical = getCanonicalHRF(p.canonical,fitParams.framePeriod);
plot(canonical.time,canonical.hrf,'k-')
if exist('myaxis') == 2,myaxis;end

%%%%%%%%%%%%%%%%%%%%%%%%
%    scaleAndOffset    %
%%%%%%%%%%%%%%%%%%%%%%%%
function [modelResponse residual beta] = scaleAndOffset(modelResponse,tSeries)

designMatrix = modelResponse;
designMatrix(:,2) = 1;
residual = [];
beta = [];
% get beta weight for the modelResponse
if ~any(isnan(modelResponse))
  beta = pinv(designMatrix)*tSeries;
  beta(1) = max(beta(1),0);
  modelResponse = designMatrix*beta;
  residual = tSeries-modelResponse;
else
  residual = tSeries;  
end

%%%%%%%%%%%%%%%%%%%%%%
%%   getFitParams   %%
%%%%%%%%%%%%%%%%%%%%%%
function p = getFitParams(params,fitParams)
    
    p.x = params(1);
    %         p.y = params(2);
    p.y = 1;
    p.std = params(3);
    % use a fixed single gaussian
    p.canonical.type = 'gamma';
    p.canonical.lengthInSeconds = 25;
    p.canonical.timelag = fitParams.timelag;
    p.canonical.tau = fitParams.tau;
    p.canonical.exponent = fitParams.exponent;
    p.canonical.offset = 0;
    p.canonical.diffOfGamma = fitParams.diffOfGamma;
    p.canonical.amplitudeRatio = fitParams.amplitudeRatio;
    p.canonical.timelag2 = fitParams.timelag2;
    p.canonical.tau2 = fitParams.tau2;
    p.canonical.exponent2 = fitParams.exponent2;
    p.canonical.offset2 = 0;
    if fitParams.fitHDR
        p.canonical.exponent = params(4);
        p.canonical.timelag = params(5);
        p.canonical.tau = params(6);
        p.canonical.diffOfGamma = fitParams.diffOfGamma;
        if fitParams.diffOfGamma
            p.canonical.exponent2 = params(7);
            p.canonical.amplitudeRatio = params(8);
            p.canonical.timelag2 = params(9);
            p.canonical.tau2 = params(10);
            p.canonical.offset2 = 0;            
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   convolveModelWithStimulus   %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function modelResponse = convolveModelWithStimulus(rfModel,stim)

% get number of frames
nFrames = size(stim.im,3);

% preallocate memory
modelResponse = zeros(1,nFrames);

for frameNum = 1:nFrames
  % multipy the stimulus frame by frame with the rfModel
  % and take the sum
  modelResponse(frameNum) = sum(sum(rfModel.*stim.im(:,:,frameNum)));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   convolveModelResponseWithHRF   %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function modelTimecourse = convolveModelResponseWithHRF(modelTimecourse,hrf)

n = length(modelTimecourse);
modelTimecourse = conv(modelTimecourse,hrf.hrf);
modelTimecourse = modelTimecourse(1:n);

%%%%%%%%%%%%%%%%%%%%%
%%   getGammaHRF   %%
%%%%%%%%%%%%%%%%%%%%%
function fun = getGammaHRF(time,p)

fun = thisGamma(time,1,p.timelag,p.offset,p.tau,p.exponent)/100;
% add second gamma if this is a difference of gammas fit
if p.diffOfGamma
  fun = fun - thisGamma(time,p.amplitudeRatio,p.timelag2,p.offset2,p.tau2,p.exponent2)/100;
end

%%%%%%%%%%%%%%%%%%%
%%   thisGamma   %%
%%%%%%%%%%%%%%%%%%%
function gammafun = thisGamma(time,amplitude,timelag,offset,tau,exponent)

% exponent = round(exponent);
% gamma function
gammafun = (((time-timelag)/tau).^(exponent-1).*exp(-(time-timelag)/tau))./(tau*factorial(exponent-1));

% negative values of time are set to zero,
% so that the function always starts at zero
gammafun(find((time-timelag) < 0)) = 0;

% normalize the amplitude
if (max(gammafun)-min(gammafun))~=0
  gammafun = (gammafun-min(gammafun)) ./ (max(gammafun)-min(gammafun));
end
gammafun = (amplitude*gammafun+offset);


%%%%%%%%%%%%%%%%%%%%%%%%%
%%   getCanonicalHRF   %%
%%%%%%%%%%%%%%%%%%%%%%%%%
function hrf = getCanonicalHRF(params,sampleRate)

hrf.time = 0:sampleRate:params.lengthInSeconds;
hrf.hrf = getGammaHRF(hrf.time,params);

% normalize to amplitude of 1
hrf.hrf = hrf.hrf / max(hrf.hrf);

%%%%%%%%%%%%%%%%%%%%
%%   getRFModel   %%
%%%%%%%%%%%%%%%%%%%%
function rfModel = getRFModel(params,fitParams)

rfModel = [];

% convert stimulus spacing to voxel magnifcation domain
if any(strcmp(fitParams.voxelScale,{'lin'}))
     x = fitParams.stimX;
    mu = params.x;
    sigma = params.std;
elseif any(strcmp(fitParams.voxelScale,{'log'}))
    x = log10(fitParams.stimX);
    mu = log10(params.x);
    sigma = params.std;
elseif any(strcmp(fitParams.voxelScale,{'erb'}))
    x = funNErb(fitParams.stimX);
    mu = funNErb(params.x);
    sigma = params.std;
else
  disp(sprintf('(pRFFit:getRFModel) Unknown voxelScale: %s',fitParams.voxelScale));
end


% now gernerate the rfModel
if any(strcmp(fitParams.rfType,{'gaussian'}))
    rfModel = makeRFGaussian(params,fitParams,x,mu,sigma);
elseif any(strcmp(fitParams.rfType,{'ROEX'}))
    rfModel = makeRFROEX(params,fitParams,x,mu,sigma);
else
  disp(sprintf('(pRFFit:getRFModel) Unknown rfType: %s',fitParams.rfType));
end


%%%%%%%%%%%%%%%%%%%%%%%%
%%   makeRFGaussian   %%
%%%%%%%%%%%%%%%%%%%%%%%%
function rfModel = makeRFGaussian(params,fitParams,x,mu,sigma)

% compute rf
% rfModel = exp(-(((fitParams.stimX-params.x).^2)/(2*(params.std^2))+((fitParams.stimY-params.y).^2)/(2*(params.std^2))));

rfModel = exp(-(((x-mu).^2)/(2*(sigma^2))+((fitParams.stimY-params.y).^2)/(2*(sigma^2))));


%%%%%%%%%%%%%%%%%%%%%%%%
%%   makeRFROEX   %%
%%%%%%%%%%%%%%%%%%%%%%%%
function rfModel = makeRFROEX(params,fitParams,x,mu,sigma)

% compute rf
% rfModel = exp(-(((fitParams.stimX-log(params.x)).^2)/(2*(params.std^2))+((fitParams.stimY-params.y).^2)/(2*(params.std^2))));
% pCF = log(params.x);
fun = @(x,mu,sigma) 1 * exp(-(x - mu).^2/2/sigma^2);
pTW = integral(@(x)fun(x,mu,sigma),-100,100); 
P = 4*mu/pTW;
g = abs(x-mu)/mu;
rfModel = (1+P*g).*exp(-P*g);

%%%%%%%%%%%%%%%%%%%%%%%%
%%   makeauditoryPRF    %%
%%%%%%%%%%%%%%%%%%%%%%%%
% function pOut = makeauditoryPRF(pIn)
% % makeauditoryPRF - turn parameters into a pRF (here, 3x3)
% %
% %  9 parameters -- all independent, needs fixing...
% %
% % this function makes an appropriately shaped pRF from parameters
% 
% if numel(pIn) ~= 9
%     error('# parameters needs to be 9 for this implementation of pRF')
% end
% 
% % turn the list into a grid
% pOut = reshape(pIn, [3 3]);

% other versions of this might take another list of params, pIn (e.g. x0,
% y0, sigma0) into a 3x3 pOut. It depends what shape we want to impose.


%%%%%%%%%%%%%%%%%%%
%    parseArgs    %
%%%%%%%%%%%%%%%%%%%
function [v scanNum x y s fitParams tSeries] = parseArgs(args);

v = [];scanNum=[];x=[];y=[];s=[];fitParams=[];tSeries = [];

% check for calling convention from interrogator
if (length(args) >= 7) && isnumeric(args{6})
  v = args{1};
  %overlayNum = args{2};
  scanNum = args{3};
  x = args{4};
  y = args{5};
  s = args{6};
  %roi = args{7};
  fitParams.dispFit = true;
  fitParams.optimDisplay = 'final';
  fitParams.algorithm = 'nelder-mead';
  fitParams.getModelResponse = false;
  fitParams.prefit = [];
  fitParams.xFlipStimulus = 0;
  fitParams.yFlipStimulus = 0;
  fitParams.timeShiftStimulus = 0;
  fitParams.betaEachScan = false;
  fitParams.justGetStimImage = false;
  fitParams.returnPrefit = false;
  fitParams.verbose = 1;
  fitParams.timelag = 1;
  fitParams.tau = 0.6;
  fitParams.exponent = 6;
  clearConstraints = false;
  getArgs({args{8:end}},{'fitTypeParams=[]'});
  if isempty(fitTypeParams)
    % no fit type params, check if we have them set in
    % the global (this is useful so that when called as an 
    % interrogator we don't have to keep setting them
    global gpRFFitTypeParams
    % if user is holding shift, then reget parameters
    if ~isempty(gcf) && any(strcmp(get(gcf,'CurrentModifier'),'shift'))
      gpRFFitTypeParams = [];
    end
    % get the parameters from the user interface if not already set
    if isempty(gpRFFitTypeParams)
      fitTypeParams = pRFGUI('pRFFitParamsOnly=1','v',v);
      if isempty(fitTypeParams) 
	v = [];
	return
      end
      gpRFFitTypeParams = fitTypeParams;
      % flag to clear the constraints
      clearConstraints = true;
    else
      % otherwise grab old ones
      disp(sprintf('(pRFFit) Using already set parameters to compute pRFFit. If you want to use different parameters, hold shift down as you click the next voxel'));
      fitTypeParams = gpRFFitTypeParams;
    end
  end
  if ~isempty(fitTypeParams)
    % if fitTypeParams is passed in (usually from pRF / pRFGUI) then
    % grab parameters off that structure
    fitTypeParamsFields = fieldnames(fitTypeParams);
    for i = 1:length(fitTypeParamsFields)
      fitParams.(fitTypeParamsFields{i}) = fitTypeParams.(fitTypeParamsFields{i});
    end
  end
  
% normal calling convention
elseif length(args) >= 5
  v = args{1};
  scanNum = args{2};
  x = args{3};
  y = args{4};
  s = args{5};
  % parse anymore argumnets
  dispFit=[];stim = [];getModelResponse = [];params = [];concatInfo = [];prefit = [];
  xFlip=[];yFlip=[];timeShiftStimulus=[];rfType=[];betaEachScan=[];fitTypeParams = [];
  dispIndex = [];dispN = [];returnPrefit = [];tSeries=[];quickPrefit=[];junkFrames=[];
  verbose = [];justGetStimImage = [];framePeriod = [];
  getArgs({args{6:end}},{'dispFit=0','stim=[]','getModelResponse=0','params=[]','concatInfo=[]','prefit=[]','xFlipStimulus=0','yFlipStimulus=0','timeShiftStimulus=0','rfType=gaussian','betaEachScan=0','fitTypeParams=[]','justGetStimImage=[]','verbose=1','dispIndex=[]','dispN=[]','returnPrefit=0','quickPrefit=0','tSeries=[]','junkFrames=[]','framePeriod=[]','paramsInfo=[]'});
  % default to display fit
  fitParams.dispFit = dispFit;
  fitParams.stim = stim;
  fitParams.optimDisplay = 'off';
  fitParams.getModelResponse = getModelResponse;
  fitParams.params = params;
  fitParams.concatInfo = concatInfo;
  fitParams.prefit = prefit;
  fitParams.xFlipStimulus = xFlipStimulus;
  fitParams.yFlipStimulus = yFlipStimulus;
  fitParams.timeShiftStimulus = timeShiftStimulus;
  fitParams.rfType = rfType;
  fitParams.betaEachScan = betaEachScan;
  fitParams.justGetStimImage = justGetStimImage;
  fitParams.verbose = verbose;
  fitParams.returnPrefit = returnPrefit;
  fitParams.junkFrames = junkFrames;
  fitParams.framePeriod = framePeriod;
  % now read in all the fields in the paramsInfo
  if ~isempty(paramsInfo)
    paramsInfoFields = fieldnames(paramsInfo);
    for iField = 1:length(paramsInfoFields)
      fitParams.(paramsInfoFields{iField}) = paramsInfo.(paramsInfoFields{iField});
    end
  end
  if ~isempty(fitTypeParams)
    % if fitTypeParams is passed in (usually from pRF / pRFGUI) then
    % grab parameters off that structure
    fitTypeParamsFields = fieldnames(fitTypeParams);
    for i = 1:length(fitTypeParamsFields)
      fitParams.(fitTypeParamsFields{i}) = fitTypeParams.(fitTypeParamsFields{i});
    end
  end
  if ~isempty(dispIndex) && ~isempty(dispN)
    % create a display string. Note that we use sprintf twice here so that
    % we can create a string with the proper amount of space padding the index
    % so that each row always displays as the same length string
    prefitOnlyStr = '';
    if isfield(fitParams,'prefitOnly') && fitParams.prefitOnly
      prefitOnlyStr = ' (prefit only)';
    end
    fitParams.dispstr = sprintf(sprintf('Voxel %%%i.f/%%i%%s: ',length(sprintf('%i',dispN))),dispIndex,dispN,prefitOnlyStr);
    end
  if getModelResponse && isempty(params)
    disp(sprintf('(pRFFit) Must pass in params when using getModelResponse'));
    fitParams.getModelResponse = false;
  end
else
  help pRFFit;
end

% some default parameters
if ~isfield(fitParams,'prefitOnly') || isempty(fitParams.prefitOnly)
  fitParams.prefitOnly = false;
end
if ~isfield(fitParams,'dispstr')
  fitParams.dispstr = '';
end
if ~isfield(fitParams,'quickPrefit') || isempty(fitParams.quickPrefit)
  fitParams.quickPrefit = false;
end
if ~isfield(fitParams,'verbose') || isempty(fitParams.verbose)
  fitParams.verbose = true;
end

% get some info about the scanNum
if ~isfield(fitParams,'framePeriod') || isempty(fitParams.framePeriod)
  fitParams.framePeriod = viewGet(v,'framePeriod');
end
if ~isfield(fitParams,'junkFrames') || isempty(fitParams.junkFrames)
  fitParams.junkFrames = viewGet(v,'junkFrames',scanNum);
end

%%%%%%%%%%%%%%%%%%%
%    getPrefit    %
%%%%%%%%%%%%%%%%%%

function fitParams = getPrefit(fitParams)

% get stimulus x,y and t
stimX = fitParams.stim{1}.x;
stimY = fitParams.stim{1}.y;
stimT = fitParams.stim{1}.t;

    if fitParams.quickPrefit
        if fitParams.verbose,disp(sprintf('(pRFFit) Doing quick prefit'));end
        % convert stimulus spacing to voxel magnifcation domain
%         StimXMin = min(stimX)*0.5;
        StimXMin = 0;
        StimXMax = max(stimX)*1.25;
        nPreFit = round(length(stimX)/10);
        StimXHWMin = 0.1;
        StimXHWMax = max(stimX);
        xHW = linspace(StimXHWMin, StimXHWMax, nPreFit);   
        if any(strcmp(fitParams.voxelScale,{'lin'}))
            xspace = linspace(StimXMin, StimXMax, nPreFit);
        elseif any(strcmp(fitParams.voxelScale,{'log'}))
            xspace = 10.^(linspace(log10(StimXMin), log10(StimXMax), nPreFit));
        elseif any(strcmp(fitParams.voxelScale,{'erb'}))
            xspace = funInvNErb(linspace(funNErb(StimXMin), funNErb(StimXMax), nPreFit));
        else
            disp(sprintf('(pRFFit:getRFModel) Unknown voxelScale: %s',fitParams.voxelScale));
        end
        if fitParams.fitHDR
        [prefitx prefity prefitrfHalfWidth prefitHDRExp] = ndgrid(xspace,1,xHW,2:2:8);
        else
        [prefitx prefity prefitrfHalfWidth] = ndgrid(xspace,1,xHW);
        end
        
    else
        % convert stimulus spacing to voxel magnifcation domain
        StimXMin = 0;
        StimXMax = max(stimX)*1.25;
        nPreFit = round(length(stimX)/5);
        StimXHWMin = 0.1;
        StimXHWMax = max(stimX);
        xHW = linspace(StimXHWMin, StimXHWMax, nPreFit);   
        if any(strcmp(fitParams.voxelScale,{'lin'}))
            xspace = linspace(StimXMin, StimXMax, nPreFit);            
        elseif any(strcmp(fitParams.voxelScale,{'log'}))
            xspace = 10.^(linspace(log10(StimXMin), log10(StimXMax), nPreFit));
        elseif any(strcmp(fitParams.voxelScale,{'erb'}))
            xspace = funInvNErb(linspace(funNErb(StimXMin), funNErb(StimXMax), nPreFit));
        else
            disp(sprintf('(pRFFit:getRFModel) Unknown voxelScale: %s',fitParams.voxelScale));
        end
        if fitParams.fitHDR
        [prefitx prefity prefitrfHalfWidth prefitHDRExp] = ndgrid(xspace,1,xHW,1:0.5:8);
        else
        [prefitx prefity prefitrfHalfWidth] = ndgrid(xspace,1,xHW);
        end
    end
    fitParams.prefit.quickPrefit = fitParams.quickPrefit;
    fitParams.prefit.n = length(prefitx(:));
    fitParams.prefit.x = prefitx(:);
    fitParams.prefit.y = prefity(:);
    fitParams.prefit.rfHalfWidth = prefitrfHalfWidth(:);
    if fitParams.fitHDR
    fitParams.prefit.HDRExp = prefitHDRExp(:);
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%    checkStimForAverages    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [stim ignoreMismatchStimfiles] = checkStimForAverages(v,scanNum,groupNum,stim,concatInfo,stimImageDiffTolerance)

ignoreMismatchStimfiles = false;  

% this function will check for some bad casses (like concat of concats etc)
% it will also check that all the component scans of an average have the
% same stim image and warn if they do not. It will then replace the stim cell
% array for the average with a single stim file, so that processing
% can continue as normal for pRFFit

% if not a cell, then ok, return
if ~iscell(stim),return,end

% first check for bad shiftList or refverseLIst
p = viewGet(v,'params',scanNum,groupNum);
if isfield(p,'params') && isfield(p.params,'shiftList') && any(p.params.shiftList~=0)
  disp(sprintf('(pRFFit) Component scan %s:%i has a shiftList that is non-zero (%s). pRFFit does not handle non-zero shifts in averages.',viewGet(v,'groupName',groupNum),scanNum,mlrnum2str(p.params.shiftList)));
  keyboard
end
if isfield(p,'params') && isfield(p.params,'reverseList') && any(p.params.reverseList~=0)
  disp(sprintf('(pRFFit) Component scan %s:%i has a reverseList that is non-zero (%s). pRFFit does not handle time-reversed time series in averages.',viewGet(v,'groupName',groupNum),scanNum,mlrnum2str(p.params.shiftList)));
  keyboard
end

% if is a cell, check to see if this is a concat or not
if ~isempty(concatInfo) && (concatInfo.isConcat)
  % this is a concat, so check each one of the elements
  [originalScanNum originalGroupNum] = viewGet(v,'originalScanNum',scanNum,groupNum);
  for i = 1:length(stim)
    % get concatInfo for original scan
    concatInfo = viewGet(v,'concatInfo',originalScanNum(i),originalGroupNum(i));
    if ~isempty(concatInfo)
      disp(sprintf('(pRFFit:checkStimForAverages) Detected concatenation of concatenations. pRFFit not implemented yet to handle this'));
      stim = [];
      keyboard
      return;
    end
    % check this next scan
    [stim{i} ignoreMismatchStimfiles] = checkStimForAverages(v,originalScanNum(i),originalGroupNum(i),stim{i},concatInfo,stimImageDiffTolerance);
    % if user has accepted all then set stimImageDiffTOlerance to infinity
    if isinf(ignoreMismatchStimfiles),stimImageDiffTolerance = inf;end
    if isempty(stim{i}),stim = [];return,end
  end
else
  % this for orignals
  [originalScanNum originalGroupNum] = viewGet(v,'originalScanNum',scanNum,groupNum);
  % if it is an original than check each element
  if ~isempty(originalScanNum)
    % check that this is not an average of a concat
    for i = 1:length(stim)
      % get concatInfo for original scan
      concatInfo = viewGet(v,'concatInfo',originalScanNum(i),originalGroupNum(i));
      if ~isempty(concatInfo)
	disp(sprintf('(pRFFit:checkStimForAverages) Detected average of a concatenations. pRFFit not implemented yet to handle this'));
	keyboard
	stim = [];
	return;
      end
      % see if it is an average of an average
      originalOfOriginalScanNum = viewGet(v,'originalScanNum',originalScanNum(i),originalGroupNum(i));
      if length(originalOfOriginalScanNum) > 1
	disp(sprintf('(pRFFit:checkStimForAverages) Detected average of an average. pRFFit not implemented yet to handle this'));
	keyboard
	stim = [];
	return;
      end
    end
    % ok, not an average of a concatenation/average so check all the stim files 
    % and warn if there are any inconsistencies
    for i = 1:length(stim)
      if ~isequalwithequalnans(stim{1}.im,stim{i}.im)    
	dispHeader
	disp(sprintf('(pRFFit:checkStimForAverages) !!! Average for %s:%i component scan %i does not match stimulus for other scans. If you wish to continue then this will use the stimfile associated with the first scan in the average !!!',viewGet(v,'groupName',groupNum),scanNum,originalScanNum(i)));
	% display which volumes are different
	diffVols = [];
	for iVol = 1:size(stim{1}.im,3)
	  if ~isequalwithequalnans(stim{1}.im(:,:,iVol),stim{i}.im(:,:,iVol))
	    diffVols(end+1) = iVol;
	  end
	end
	disp(sprintf('(pRFFit) Stimulus files are different at %i of %i vols (%0.1f%%): %s',length(diffVols),size(stim{1}.im,3),100*length(diffVols)/size(stim{1}.im,3),num2str(diffVols)));
	if 100*(length(diffVols)/size(stim{1}.im,3)) < stimImageDiffTolerance
	  disp(sprintf('(pRFFit) This could be for minor timing inconsistencies, so igorning. Set stimImageDiffTolerance lower if you want to stop the code when this happens'));
	else
	  % ask user if they want to continue (only if there is a difference of more than 10 vols	  
	  ignoreMismatchStimfiles = askuser('Do you wish to continue',1);
	  if ~ignoreMismatchStimfiles
	    stim = [];
	    return;
	  end
	end
	dispHeader
      end
    end
    % if we passed the above, this is an average of identical
    % scans, so just keep the first stim image since they are all the same
    stim = stim{1};
  end
end

%%%%%%%%%%%%%%%%%
%    getStim    %
%%%%%%%%%%%%%%%%%
function stim = getStim(v,scanNum,fitParams)
% get stimfile
% stimfile = viewGet(v,'stimfile',scanNum);
% % get volume to trigger ratio
% volTrigRatio = viewGet(v,'auxParam','volTrigRatio',scanNum);
% check if global matches
groupNum = viewGet(v,'curGroup');
global gpRFFitStimImage
if (isfield(fitParams,'recomputeStimImage'))
    disp(sprintf('(pRFFit) Computing stim image'));
    
    % create a volume of dimensions x,y,t with the stimulus image.
    % stim.x and stim.y are the X and Y coordinates. stim.t is the array of times at which image is taken.
    % stim needs to be in the following format
    %     stim{i}.x
    %     stim{i}.y
    %     stim{i}.t
    %     stim{i}.im
    
    stim = makeAuditoryStimImage(fitParams.d,fitParams,1,scanNum);
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%    applyConcatFiltering    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tSeries = applyConcatFiltering(tSeries,concatInfo,runnum)

% apply the same filter as original data
% check for what filtering was done
tSeries = tSeries(:);

% apply detrending (either if concatInfo does not say what it did or if
% the filterType field has detrend in it)
if ~isfield(concatInfo,'filterType') || ~isempty(findstr('detrend',lower(concatInfo.filterType)))
    tSeries = eventRelatedDetrend(tSeries);
end

% apply hipass filter
if isfield(concatInfo,'hipassfilter') && ~isempty(concatInfo.hipassfilter{runnum})
    % check for length match
    if ~isequal(length(tSeries),length(concatInfo.hipassfilter{runnum}))
        disp(sprintf('(pRFFit:applyConcatFiltering) Mismatch dimensions of tSeries (length: %i) and concat filter (length: %i)',length(tSeries),length(concatInfo.hipassfilter{runnum})));
    else
        tSeries = real(ifft(fft(tSeries) .* repmat(concatInfo.hipassfilter{runnum}', 1, size(tSeries,2)) ));
    end
end

% project out the mean vector
if isfield(concatInfo,'projection') && ~isempty(concatInfo.projection{runnum})
    projectionWeight = concatInfo.projection{runnum}.sourceMeanVector * tSeries;
    tSeries = tSeries - concatInfo.projection{runnum}.sourceMeanVector'*projectionWeight;
end

% now remove mean
tSeries = tSeries-repmat(mean(tSeries,1),size(tSeries,1),1);

% make back into the right dimensions
tSeries = tSeries(:)';

%%%%%%%%%%%%%
%%   r2d   %%
%%%%%%%%%%%%%
% function degrees = r2d(angle)
% 
% degrees = (angle/(2*pi))*360;
% 
% % if larger than 360 degrees then subtract
% % 360 degrees
% while (sum(degrees>360))
%   degrees = degrees - (degrees>360)*360;
% end
% 
% % if less than 360 degreees then add 
% % 360 degrees
% while (sum(degrees<-360))
%   degrees = degrees + (degrees<-360)*360;
% end
