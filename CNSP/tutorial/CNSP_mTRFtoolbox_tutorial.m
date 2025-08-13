% Cognition and Natural Sensory Processing (CNSP) Initiative
%
% This example script loads a preprocessed publicly available dataset
% (you can use any of the dataset in the CNSP resources).
%
% Note:
% This code was written with the assumption that all subjects were
% presented with the same set of stimuli. Hence, we use a single stimulus
% file (dataStim.mat) that applies to all subjects. This is compatible
% with scenarios with randomise presentation orders. In that case, the
% EEG/MEG trials should be sorted to match the single stimulus file.
% The original order is preserved in a specific CND variable. If distinct
% subjects were presented with different stimuli, it is necessary to
% include a stimulus file per participant.
%
% CNSP-Initiative
% https://github.com/CNSP-Workshop/CNSP-resources
% https://cnspworkshop.net
%
% Author:  Aaron Nidiffer
% Copyright 2023 - Giovanni Di Liberto
%                  Nathaniel Zuk
%                  Michael Crosse
%                  Aaron Nidiffer
%                  Giorgia Cantisani
%                  (see license file for details)
% Last update: 14 September 2023

clear
close all
clc

restoredefaultpath; 
run addPathDependencies.m

%% Parameters - Natural speech listening experiment
%**************************************************
dataset = 'LalorNatSpeech';
datafolder = sprintf('../datasets/%s/dataCND/',dataset);

sub = 10; % cherry pick a good subject
downFs = 64; % downsample for speed

% TRF hyperparameters
% When we inspect TRFs, we like to see a bit of time before stimulus
% "onset" (0 lag) to get a sense of the baseline fluctuations. Similarly,
% we inspect a bit beyond how long we think the response will last.
tmin = -200; 
tmax = 600;
%lambdas = 10.^(-2:2:2); % small set of lambdas (quick)
lambdas = 10.^(-2:8); % larger set of lambdas (slower)
dirTRF = 1; % Forward TRF model

% Note: backward models (dirTRF = -1) with many electrodes and large 
% time-windows can require long computational times. So, we suggest 
% reducing the dimensionality if you are just playing around with the code 
% (e.g., select only few electrodes and/or reduce the TRF window)


%% Loading and preparing EEG and stimulus features
%*************************************************

% Loading Stimulus data
stimFilename = sprintf('%sdataStim.mat',datafolder);
fprintf('Loading stimulus data \n')
load(stimFilename,'stim')

% Downsampling stim if necessary
if downFs < stim.fs
    stim = cndDownsample(stim,downFs);
end

% Selecting features of interest
% envelope = 1
stimE = stim;
stimE.names = stimE.names{1};
stimE.data = stimE.data(1,:);

% word onset = 2
stimO = stim;
stimO.names = stimO.names{2};
stimO.data = stimO.data(2,:); 

% spectrogram = 3
stimS = stim;
stimS.names = stimS.names{3};
stimS.data = stimS.data(3,:); 

% phonetic features = 4
stimF = stim;
stimF.names = stimF.names{4};
stimF.data = stimF.data(4,:); 

% Loading EEG data
neuralFilename = sprintf('%spre_dataSub%d.mat',datafolder,sub);

fprintf('Loading EEG data, subject %d \n',sub)
eeg = importdata(neuralFilename);
ntrials = length(eeg.data);

% Downsampling eeg if necessary
if downFs < eeg.fs
    eeg = cndDownsample(eeg,downFs);
end

% Making sure that stim and neural data have the same length
% The trial may end a few seconds after the end of the audio
% e.g., the neural data may include the break between trials
% It would be best to do this chunking at preprocessing, but let's
% check here, just to be sure
[stimE,eeg] = cndCheckStimNeural(stimE,eeg);
[stimO,eeg] = cndCheckStimNeural(stimO,eeg);
[stimS,eeg] = cndCheckStimNeural(stimS,eeg);
[stimF,eeg] = cndCheckStimNeural(stimF,eeg);

% Standardise stim data (preserving the ratio between features)
% This is thought for continuous signals e.g., speech envelope, neural
stimE = cndNormalise(stimE);
stimS = cndNormalise(stimS);
% stim O/F/other discrete features?
% continuous value, discrete time features (dissimilarity, surprisal,
% cohort entropy, etc)?

% Standardise neural data (preserving the ratio between channels)
eeg = cndNormalise(eeg);

% Just to initialize the save file since all other save commands use
% the '-append' flag. Only if it doesn't already exist.
if ~exist('CNSP_tutorial_extras.mat','file')
    save('CNSP_tutorial_extras.mat','sub')
end

%% Fitting forward (encoder) model
%*********************************

clear stats model pred r I

% The TRF represents the linear mapping from stimulus to response and is
% computed for each trial individually - accounting for the unique content
% of each trial's stimulus.
rndTrial = randi(ntrials);
model1 = mTRFtrain(stimE.data{rndTrial},eeg.data{rndTrial},eeg.fs,dirTRF,tmin,tmax,lambdas(8));

% Display the single-trial model
figure(1)
subplot(2,1,1) % Weights
plot(model1.t,squeeze(model1.w))
title('Env TRF')
xlabel('Time-lag (ms)')
ylabel('Magnitude (a.u.)')
xlim([tmin+50,tmax-50])
subplot(2,1,2)% GFP
area(model1.t,squeeze(std(model1.w,1,3)))
title('TRF Global Field Power')
xlabel('Time-lag (ms)')
ylabel('Magnitude (a.u.)')
xlim([tmin+50,tmax-50])

pause(5);
tmin = -200;
tmax = 600;

% We fit a better model if we average across more data (trials). This works
% despite the unique stimulus content because the mappings should be the
% same across unique stimuli.
model2 = mTRFtrain(stimE.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas(6));

% Display the averaged model
figure(2)
subplot(2,1,1) % Weights
plot(model2.t,squeeze(model2.w))
title('Env TRF')
xlabel('Time-lag (ms)')
ylabel('Magnitude (a.u.)')
xlim([tmin+50,tmax-50])
subplot(2,1,2)% GFP
area(model2.t,squeeze(std(model2.w,1,3)))
title('TRF Global Field Power')
xlabel('Time-lag (ms)')
ylabel('Magnitude (a.u.)')
xlim([tmin+50,tmax-50])

% There was a question about lambda selection, so here are several models
% with different levels of regularization plotted side-by-side. In the
% above code, we plot all the channels in a "butterfly plot" and here we're
% plotting only one channel, hand (cherry)-picked for optimal
% demonstration. It's actually not a great demonstration of the
% high-frequency noise Mick (or someone) mentioned. I think these data are
% too good! Anyway, it does demonstrate the smoothing effect of
% regularization

% Subject 10 parameters to pick the best cherry.
ch=58; tr=17;

lambdas2 = [0 10.^(-4:2:10)];lambdas2 = [0 10.^(1:5)]; % Just to show the value that are relevant for this particular subject
figure(13) % I'm lazy. Not going to update all the figure indices. I forsaw this happening. sigh. %figure(fI); fI=fI+1;
hold on

for ll = 1:length(lambdas2)
    model = mTRFtrain(stimE.data{tr},eeg.data{tr},eeg.fs,dirTRF,tmin,tmax,lambdas2(ll));

    plot(model.t,zscore(squeeze(model.w(1,:,ch))))
    title('Env TRF')
    xlabel('Time-lag (ms)')
    ylabel('Magnitude (zscore)')
    xlim([tmin+50,tmax-50])

end

legend(string(lambdas2))


%% Optimizing model - cross-validation
%*************************************

clear stats model pred r I

% The ultimiate goal of model fitting is evaluating how well it can predict
% data. We could use the average model above to predict its individual
% trials and evaluate those predictions:

[~,stats] = mTRFpredict(stimE.data,eeg.data,model2);

% but since each predicted trial was part of the average model (i.e.,
% the model is predicting itself to some degree) we are susceptible to some
% overfitting. To combat this, we cross-validate our model. That means
% we'll fit it using some trials and predict the responses on others. Here
% we use "leave-one-out" cross-validation: fit on N-1 trials and test on
% the left-out trial.

% change some TRF hyperparameters to focus on "predictable" lags
tmin = 0;
tmax = 400;

% TRF crossvalidation - determining optimal regularization parameter
stats = mTRFcrossval(stimE.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas);

% Calculate optimal lambda and model performance
[~,bestLambda] = max(mean(stats.r,[1 3]));
r_e(1,:) = squeeze(mean(stats.r(:,bestLambda,:),1));

% Fit TRF model with optimal regularization parameter
model3 = mTRFtrain(stimE.data,eeg.data,eeg.fs,dirTRF,-200,600,lambdas(bestLambda));

% Display the optimal model
figure(3)
subplot(2,1,1) % Weights
plot(model3.t,squeeze(model3.w))
title('Env TRF')
xlabel('Time-lag (ms)')
ylabel('Magnitude (a.u.)')
xlim([tmin,tmax])
subplot(2,1,2)% GFP
area(model3.t,squeeze(std(model3.w,1,3)))
title('TRF Global Field Power')
xlabel('Time-lag (ms)')
ylabel('Magnitude (a.u.)')
xlim([tmin,tmax])


%% Predicting unseen data - nested crossvalidation
%*************************************************

clear stats model pred r I

% In the previous example, we have an opportunity for our model to be 
% overfit due to the optimization step. To guard against overfitting, we
% can remove some data from the optimization step to be used to evaluate 
% the optimized model. A simple method to do this might select one set of
% test trials and optimize on all others. Here we let each trial be the
% test trial on separate iterations, optimize (cross-validate) a model from
% other trials, and average the test trial prediction accuracy at the end.
for tt = 1:ntrials
    % separate the training and test data for this outer fold
    rtrain = eeg.data; strain = stimE.data;
    rtrain(tt)=[]; strain(tt)=[];
    rtest = eeg.data(tt); stest = stimE.data(tt);

    % Perform inner LOO crossval on only the training trials
    stats = mTRFcrossval(strain,rtrain,eeg.fs,dirTRF,tmin,tmax,lambdas);
    
    % Calculate optimal lambda, cross-validated performance
    [~,I]=max(mean(stats.r,[1 3]));
    r_crossval(tt,:) = squeeze(mean(stats.r(:,I,:),1));

    % fit final model with all training trails
    model = mTRFtrain(strain,rtrain,eeg.fs,dirTRF,tmin,tmax,lambdas(I));

    % With this model, we can predict EEG of the test trial from the
    % stimulus feature of that trial and evaluate the accuracy of that
    % prediction
    [~,stats] = mTRFpredict(stest,rtest,model);
    r_leftout(tt,:) = stats.r;
end

% Compare crossvalidated and left-out performance
figure(4)
bar([mean(r_crossval,[1 2]) mean(r_leftout,[1 2])])
xticklabels({'Cross-validated','Left-out'})
xlabel('Model Fit Step')
ylabel('Prediction Accuracy')
ylim([0.04 0.05])

% Womp womp. Unseen is marginally better, likely because 1) we used LOO cross-
% validation, so the models are all very similar and 2) the model is not
% overfitting (lots of clean data, only 1 stimulus feature to fit, etc).
% Will be more important when overfitting is more of an issue (poor SNR,
% low data, sparse stimulus).


%% Model evaluation
%******************

clear stats model pred r I

% Our prediction scores are typically low (relative to the entire
% range of correlation coefficients), so how do we know if our model is
% performing better than "chance." One way we test this is by randomly
% shuffling trial labels and iteratively fitting models and testing their
% "null" performance.
niter = 1000;

% We must make sure all trials are the same length
min_length = min(cellfun('length',stimE.data));

stimE2 = stimE; eeg2 = eeg;
for tt = 1:ntrials
    stimE2.data{tt} = stimE2.data{tt}(1:min_length,:);
    eeg2.data{tt} = eeg2.data{tt}(1:min_length,:);
end

% find our "observed" prediction accuracy (we already know our best lambda to make execution faster***)
stats = mTRFcrossval(stimE2.data,eeg2.data,eeg2.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
r_alt(1,:) = squeeze(mean(stats.r,1));

if ~exist('CNSP_tutorial_extras.mat','file') % Takes too long to demonstrate

    % iteratively fit randomized (shuffled) models and see if that null
    % model can properly predict data. Here we're shuffling the trial
    % labels, but shuffling can be across time or features, depending on
    % the question.
    for ii = 1:niter
        for tt = 1:ntrials
            % Remove current trial (tt) from test trial set
            train_tr = 1:ntrials; train_tr(tt)=[];
            
            % Shuffle the labels for one of the inputs.
            shuf_tr = train_tr(randperm(ntrials-1));
            
            % Fit the null model
            % (pros and cons of optimization at this step)
            model = mTRFtrain(stimE2.data(shuf_tr),eeg2.data(train_tr),eeg2.fs,dirTRF,tmin,tmax,lambdas(bestLambda),'Verbose',false);

            % Evaluate it's performance (matched stim/resp)
            [~,stats]=mTRFpredict(stimE2.data{tt},eeg2.data{tt},model,'Verbose',false);
            r_tr(tt,:) = stats.r;
        end
        r_null1(ii,:) = mean(r_tr,1);

        % Just messing around
        stats = mTRFcrossval(stimE2.data(randperm(ntrials)),eeg2.data,eeg2.fs,dirTRF,tmin,tmax,lambdas(bestLambda),'Verbose',false);
        r_null2(ii,:) = squeeze(mean(stats.r,1));
    end
    save('CNSP_tutorial_extras.mat','r_null1','r_null2','-append')

else % preload results
    load('CNSP_tutorial_extras.mat','r_null1'); r_null=r_null1;
    % load('CNSP_tutorial_extras.mat','r_null2'); r_null=r_null2;
end

% plot the results
[N,edges] = histcounts(mean(r_null,2),-0.1:0.002:0.1);
figure(5)
plot(edges(2:end)-diff(edges)/2,N./niter,'LineWidth',2)
hold on
stem(mean(r_alt),max(N./niter),'.','LineWidth',2)
xlim([-0.02 0.08])
xlabel('Prediction Accuracy (r)')
ylabel('Rel. Prob.')
legend({'null distribution','observed data'})

% find the p-value, proportion of null models that perform the same or
% better than our alternative model.
p = mean(r_null>=r_alt);
 


%% Model comparison and multi-feature models
%*******************************************

clear stats model pred r I

% Part of our research hypothesis might involve comparing between several
% candidate models or determining whether certain features add value beyond
% others. We can perform model selection via forward and backward selection
% just as in linear regression by adding or taking away features
% (y~m1x1 vs `)

% Fit and evaluate several feature models:
% Envelope, env, E
stats = mTRFcrossval(stimE.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
r_e(1,:) = squeeze(mean(stats.r,1));

% Spectrogram, sgram, S
stats = mTRFcrossval(stimS.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
r_s(1,:) = squeeze(mean(stats.r,1));

% Phonetic Features, fea, F
stats = mTRFcrossval(stimF.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
r_f(1,:) = squeeze(mean(stats.r,1));

% Joint spectrogram + phonetic feature model
stimFS = stimF;
for tt = 1:ntrials
    stimFS.data{tt} = [stimF.data{tt} stimS.data{tt}];
end
stats = mTRFcrossval(stimFS.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
r_fs(1,:) = squeeze(mean(stats.r(:,ch),1));

% Compare models
figure(6)
bar([mean(r_e) mean(r_s) mean(r_f) mean(r_fs)])
xticklabels({'env','sgram','fea','sgram+fea'})
xlabel('Model')
ylabel('Prediction Accuracy')

% We must take care not to compare models with drastically different
% numbers of parameters. Here the FS model has 35 feature parameters while
% the constituent models (S and F) have 16 and 19, respectively. If we're
% worried about overfitting, we can compare a full model (FS) to a model
% where the feature of interest (F) is shuffled (FshufS)

% We must make sure all trials are the same length
min_length = min(cellfun('size',eeg.data,1));

stimF2 = stimF; stimS2 = stimS; eeg2 = eeg;
for tt = 1:ntrials
    stimF2.data{tt} = stimF2.data{tt}(1:min_length,:);
    stimS2.data{tt} = stimS2.data{tt}(1:min_length,:);
    eeg2.data{tt} = eeg2.data{tt}(1:min_length,:);
end

% We don't need a distribution, so we'll take the average performance
% across 50 iterations.
t = tic;
if 0
nfeat = size(stimF2.data{1},2);
for ii = 1:50
    % Construct a shuffled F stimulus feature for each iteration
    stimFshuffS = stimF;
    I = randperm(ntrials);
    for tt = 1:ntrials
        % Shuffle feature labels
        stimFshuffS.data{tt} = [stimF.data{tt}(:,randperm(nfeat)) stimS.data{tt}]; 
        
        % Shuffle trial labels
        % stimFshuffS.data{tt} = [stimF2.data{I(tt)} stimS2.data{tt}];
    end
% 
    stats = mTRFcrossval(stimFshuffS.data,eeg.data,eeg2.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
    r_fshufs(ii,:) = squeeze(mean(stats.r,1));
end
save('CNSP_tutorial_extras.mat','r_fshufs','-append')
else
    load('CNSP_tutorial_extras.mat','r_fshufs')
end
toc(t)

% Compare model performance
figure(7)
bar([mean(r_s) mean(mean(r_fshufs)) mean(r_fs)])
xticklabels({'sgram','sgram+fea_s_h_f','sgram+fea'})
xlabel('Model')
ylabel('Prediction Accuracy')


%% Fitting and evaluating decoder models
%***************************************

clear stats model pred r I

% Forward models are nice because they produce interpretable weights.
% However the model performance can be quite low. We can improve our
% sensitivity at the expense of interpretability by fitting backward
% (decoder) models. Instead of attempting to predict 128 EEG signals from
% one stimulus feature, we use all 128 EEG signals to reconstruct a single
% stimulus feature.

% Change hyperparameters
tmin = -200;
tmax = 600;
dirTRF = -1; % This makes us go backwards

% Fit a backward TRF - takes a lot longer
model4 = mTRFtrain(stimE.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas(8));

% Display the decoder model
figure(8)
subplot(2,1,1) % Weights
plot(model4.t,squeeze(model4.w))
title('Env TRF')
xlabel('Time-lag (ms)')
ylabel('Magnitude (a.u.)')
xlim([-tmax+50,-tmin-50])
subplot(2,1,2)% GFP
area(model4.t,squeeze(std(model4.w,1,1)))
title('TRF Global Field Power')
xlabel('Time-lag (ms)')
ylabel('Magnitude (a.u.)')
xlim([-tmax+50,-tmin-50])

drawnow

% Change hyperparameters
tmin = 0;
tmax = 400;

% Cross-validate the decoder model
stats = mTRFcrossval(stimE.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas);
r_e_Decoder = max(mean(stats.r));

% Compare forward and backward performance
figure(9)
bar([mean(r_e) max(r_e) r_e_Decoder])
xticklabels({'avg forward','max forward','backward'})
xlabel('Predictions')
ylabel('Prediction Accuracy')


%% Single-lag reconstructions
%****************************

clear stats model pred r I


% Change hyperparameters
tmin = -200;
tmax = 600;
if ~exist('CNSP_tutorial_extras.mat','file') % again takes forever, we'll just preload
    t = tic;
    % the mTRFtoolbox can evaluate each lag individually by including
    % 'type','single' in the inputs
    stats = mTRFcrossval(stimE.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas(8),'type','single');
    r_sl1(1,:) = squeeze(mean(stats.r,1));

    % fitting all lags at once may reduce some temporal smear. You can fit
    % a normal multi-lag model and switch it to a single-lag model with a
    % trick.
    for tt = 1:ntrials
        % Choose training set (all but current trial, tt)
        train_tr = 1:ntrials; train_tr(tt)=[];

        % fit decoder
        model = mTRFtrain(stimE.data(train_tr),eeg.data(train_tr),eeg.fs,dirTRF,tmin,tmax,lambdas(8));

        % convert model structure to single-lag
        model.type = 'single';
        model.b = repmat(model.b,size(model.t));

        % predict single-lag reconstruction scores
        [~,stats] = mTRFpredict(stimE.data(tt),eeg.data(tt),model);
        r(tt,:) = squeeze(stats.r);
    end
    r_sl2 = mean(r,1);
    save('CNSP_tutorial_extras.mat','r_sl1','r_sl2','-append')
    toc(t)
else
    load('CNSP_tutorial_extras.mat','r_sl1','r_sl2')
end

% Inspect the time-series
figure(10)
hold on
plot(-model4.t,r_sl1,'LineWidth',2)
plot(-model4.t,r_sl2,'LineWidth',2)
xlabel('Time-Lag (ms)')
ylabel('Reconstruction Accuracy (r)')
legend({'single-fit','multi-fit'})

%% Partial predictions
%******************************

clear stats model pred r I
% Sometimes we want to investigate whether one stimulus is tracked by EEG
% activity beyond what could be attributed to other potentially correlated 
% features. We can use predictions generated by the TRF to remove the

% Change hyperparameters
tmin = 0;
tmax = 400;
dirTRF = 1; % back to forward

% Remove the effects of S from the EEG.
eeg_noS = eeg; eeg_noF = eeg;
for tt = 1:ntrials
    % Fit single-trial model
    model = mTRFtrain(stimS.data{tt},eeg.data{tt},eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
    % predict itself
    pred = mTRFpredict(stimS.data{tt},eeg.data{tt},model);
    % subtract the prediction
    eeg_noS.data{tt} = eeg.data{tt}-pred;
    
end

% Optimize and S model on data with no S
stats = mTRFcrossval(stimS.data,eeg_noS.data,eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
r_s_noS(1,:) = squeeze(mean(stats.r,1));

% Optimize and F model on data with no S
stats = mTRFcrossval(stimF.data,eeg_noS.data,eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
r_f_noS(1,:) = squeeze(mean(stats.r,1));

% Compare model performances
figure(11)
bar([mean(r_fs) mean(r_f) mean(r_f_noS) mean(r_s) mean(r_s_noS)])
xticklabels({'fs','f','f(prtld s)','s','s(prtld s)'})
xlabel('model')
ylabel('Prediction Accuracy')

% Another approach that is roughly equivalent but generally preferred
% involves generating predictions of each feature you're interested in
% measuring and controling for and performing a partial correlation against
% the actual EEG.

for tt = 1:ntrials
    % Choose training set (all but current trial, tt)
    train_tr = 1:ntrials; train_tr(tt)=[];

    % fit F model and predict EEG
    model = mTRFtrain(stimF.data(train_tr),eeg.data(train_tr),eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
    predF = mTRFpredict(stimF.data{tt},eeg.data{tt},model);

    % fit S model and predict EEG
    model = mTRFtrain(stimS.data(train_tr),eeg.data(train_tr),eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda));
    predS = mTRFpredict(stimS.data{tt},eeg.data{tt},model);

    % Loop through the channels to compute partial correlations
    for cc = 1:size(eeg.data{1},2)
        r_f_parS(tt,cc) = partialcorr(eeg.data{tt}(:,cc),predF(:,cc),predS(:,cc));
    end

end

% Compare model performances
figure(12)
bar([mean(r_fs) mean(r_f) mean(r_f_noS) mean(mean(r_f_parS))])
xticklabels({'fs','f','f(trfpar s)','f(parcorr s)'})
xlabel('model')
ylabel('Prediction Accuracy')

