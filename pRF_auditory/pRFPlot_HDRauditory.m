%% To do
% plot error bars
%   calculate HDR function then average rather than average params - this
%   will allow error bar - include scaling

function pRFPlot_HDRauditory(v,overlayNum,scanNum,x,y,z,roi)
% pRFPlot_HDRauditory.m
%
%        $Id$
%      usage: pRFPlot_HDRauditory() is an interrogator function
%         by: Ben Gurer
%       date: 18-Oct-2016
%    purpose: plot estimated HDR from pRF analysis

% check arguments
if ~any(nargin == [7])
  help pRFPlot
  return
end

% see if the shift key is down
%shiftDown = any(strcmp(get(viewGet(v,'figureNumber'),'CurrentModifier'),'shift'));
shiftDown = any(strcmp(get(viewGet(v,'figureNumber'),'SelectionType'),'extend'));

% check if pRF has been run
a = viewGet(v,'Analysis');
if ~isfield(a,'type') || ~strcmp(a.type,'pRFAnal')
  disp(sprintf('(pRFPlot) pRF analysis has not been run on this scan'));
  return
end

% get the d
d = viewGet(v,'d',scanNum);
if isempty(d),disp(sprintf('(pRFPlot) Could not find d structure for this scan'));return,end

% get the parametrs of the pRF fit
r2 = viewGet(v,'overlayData',scanNum,viewGet(v,'overlayNum','r2'));
if isempty(r2)
  disp(sprintf('(pRFPlot) pRF analysis has not been run on this scan'));
  return
end

threshold = 0.1;
[r2index r2v] = find(d.r2>=threshold);
paramsr2thres = d.params(:,r2index);


hdrAv = mean(d.params,2);
hdrE = std(d.params,2);

dispHDRFit(hdrAv,d.fitParams)

hdrAvr2 = mean(paramsr2thres,2);
dispHDRFit(hdrAvr2,d.fitParams)

function averHDR(d
p = getFitParams(params,fitParams);
canonical
function dispHDRFit(params,fitParams)
figure
% mlrSmartfig('pRFFit_getModelResidual','reuse');
% clf
% subplot(4,4,[1:3 5:7 9:11 13:15]);
% %plot(fitParams.stimT(fitParams.junkFrames+1:end),tSeries,'k-');
% plot(tSeries,'k-');
% hold on
% %plot(fitParams.stimT(fitParams.junkFrames+1:end),modelResponse,'r-');
% plot(modelResponse,'r-');
% xlabel('Time (sec)');
% ylabel('BOLD (% sig change)');
p = getFitParams(params,fitParams);
% e = getFitParams(params,fitParams); 
titleStr = sprintf('x: %s y: %s rfHalfWidth: %s',mlrnum2str(p.x),mlrnum2str(p.y),mlrnum2str(p.std));
titleStr = sprintf('%s\n(timelag: %s tau: %s exponent: %s)',titleStr,mlrnum2str(p.canonical.timelag),mlrnum2str(p.canonical.tau),mlrnum2str(p.canonical.exponent));
if p.canonical.diffOfGamma
  titleStr = sprintf('%s - %s x (timelag2: %s tau2: %s exponent2: %s)',titleStr,mlrnum2str(p.canonical.amplitudeRatio),mlrnum2str(p.canonical.timelag2),mlrnum2str(p.canonical.tau2),mlrnum2str(p.canonical.exponent2));
end
title(titleStr);
axis tight

% subplot(4,4,[8 12 16]);
% imagesc(fitParams.stimX(:,1),fitParams.stimY(1,:),flipud(rfModel'));
% axis image;
% hold on
% hline(0);vline(0);
% 
% subplot(4,4,4);cla
% p = getFitParams(params,fitParams);
canonical = getCanonicalHRF(p.canonical,fitParams.framePeriod);
plot(canonical.time,canonical.hrf,'k-')
if exist('myaxis') == 2,myaxis;end

function dispModelFit(params,fitParams,modelResponse,tSeries,rfModel)

mlrSmartfig('pRFPlot_HDRauditory','reuse');
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