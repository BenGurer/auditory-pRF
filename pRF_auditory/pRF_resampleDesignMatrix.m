function ResampledModelResponse = pRF_resampleDesignMatrix(thisModelResponse,params,fitParams)

designSupersampling = fitParams.d.designSupersampling;
acquisitionDelay = fitParams.acquisitionDelay;
tr = fitParams.d.tr;

sampleNumber = floor(rem(acquisitionDelay,tr)*designSupersampling/tr)+1;
thisModelResponse = squeeze(thisModelResponse);
thisModelResponse = reshape(thisModelResponse,[length(thisModelResponse)/designSupersampling,designSupersampling]);

ResampledModelResponse = thisModelResponse(:,sampleNumber);

ds = mrDownsample(s, factor, sampleNumber)

ResampledModelResponse = squeeze(ResampledModelResponse);