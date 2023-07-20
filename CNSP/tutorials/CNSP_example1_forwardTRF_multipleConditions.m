% Cognition and Natural Sensory Processing (CNSP) Initiative
% Example 1 - Forward TRF
%
% This example script loads and preprocesses a publicly available dataset
% (you can use any of the dataset in the CNSP resources). Then, the script
% runs a typical forward TRF analysis.
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
% https://cnsp-resources.readthedocs.io/
% https://github.com/CNSP-Workshop/CNSP-resources
% https://cnspworkshop.net
%
% Author: Giovanni M. Di Liberto
% Copyright 2021 - Giovanni Di Liberto
%                  Nathaniel Zuk
%                  Michael Crosse
%                  Aaron Nidiffer
%                  Giorgia Cantisani
%                  (see license file for details)
% Last update: 19 July 2023

clear all
close all

run addPathDependencies.m

%% Parameters - Natural speech listening experiment
dataMainFolder = '../datasets/musicImagery/';

dataCNDSubfolder = 'dataCND/';

reRefType = 'Avg'; % or 'Mastoids'
bandpassFilterRange = [1,8]; % Hz (indicate 0 to avoid running the low-pass
                          % or high-pass filters or both)
                          % e.g., [0,8] will apply only a low-pass filter
                          % at 8 Hz
downFs = 64; % Hz. *** fs/downFs must be an integer value ***

neuralFilenames = dir([dataMainFolder,dataCNDSubfolder,'dataSub*.mat']);
nSubs = length(neuralFilenames);

if downFs < bandpassFilterRange(2)*2
    disp('Warning: Be careful. The low-pass filter should use a cut-off frequency smaller than downFs/2')
end

%% Preprocess EEG - Natural speech listening experiment
for sub = 1:nSubs
    % Loading EEG data
    neuralFilename = [dataMainFolder,dataCNDSubfolder,neuralFilenames(sub).name];
    disp(['Loading EEG data: ',neuralFilenames(sub).name])
    neural = importdata(neuralFilename); % it should contain only one variable (e.g., 'neural', 'eeg', 'meg')

    neural = cndNewOp(neural,'Load'); % Saving the processing pipeline in the neural struct

    % Filtering - LPF (low-pass filter)
    if bandpassFilterRange(2) > 0
        hd = getLPFilt(neural.fs,bandpassFilterRange(2));
        
        % A little coding trick - for loop vs cellfun
        if (0)
            % Filtering each trial/run with a for loop
            for ii = 1:length(neural.data)
                neural.data{ii} = filtfilthd(hd,neural.data{ii});
            end
        else
            % Filtering each trial/run with a cellfun statement
            neural.data = cellfun(@(x) filtfilthd(hd,x),neural.data,'UniformOutput',false);
        end
        
        % Filtering external channels
        if isfield(neural,'extChan')
            for extIdx = 1:length(neural.extChan)
                neural.extChan{extIdx}.data = cellfun(@(x) filtfilthd(hd,x),neural.extChan{extIdx}.data,'UniformOutput',false);
            end
        end
        
        neural = cndNewOp(neural,'LPF');
    end
    
    % Downsampling EEG and external channels
    if downFs < neural.fs
        neural = cndDownsample(neural,downFs);
    end
    
    % Filtering - HPF (high-pass filter)
    if bandpassFilterRange(1) > 0 
        hd = getHPFilt(neural.fs,bandpassFilterRange(1));
        
        % Filtering EEG data
        neural.data = cellfun(@(x) filtfilthd(hd,x),neural.data,'UniformOutput',false);
        
        % Filtering external channels
        if isfield(neural,'extChan')
            for extIdx = 1:length(neural.extChan)
                neural.extChan{extIdx}.data = cellfun(@(x) filtfilthd(hd,x),neural.extChan{extIdx}.data,'UniformOutput',false);
            end  
        end
        
        neural = cndNewOp(neural,'HPF');
    end
    
    % Replacing bad channels
    if isfield(neural,'chanlocs')
        for tr = 1:length(neural.data)
            neural.data{tr} = removeBadChannels(neural.data{tr}, neural.chanlocs);
        end
    end
    
    % Re-referencing EEG data
    neural = cndReref(neural,reRefType);
    
    % Removing initial padding (specific to this dataset)
    if isfield(neural,'paddingStartSample')
        for tr = 1:length(neural.data)
            neural.data{tr} = neural.data{tr}(neural.paddingStartSample,:);
            for extIdx = 1:length(neural.extChan)
                neural.extChan{extIdx}.data = neural.extChan{extIdx}.data{tr}(1+neural.paddingStartSample,:);
            end
        end
    end
    
    % Saving preprocessed data
    neuralPreFilename = [dataMainFolder,dataCNDSubfolder,'pre_',neuralFilenames(sub).name];
    disp(['Saving preprocessed EEG data: pre_',neuralFilenames(sub).name])
    save(neuralPreFilename,'neural')
end

%% The multivariate Temporal Response Function

% TRF hyperparameters
tmin = -200;
tmax = 600;
lambdas = [1e-2,1e0,1e2]; % small set of lambdas (quick)
% lambdas = [1e-6,1e-3,1e-4,1e-3,1e-2,1e-1,1e0,1,1e2,1e3,1e4]; % larger set of lambdas (slower)
dirTRF = 1; % Forward TRF model
stimIdx = 1; % 1: env; 2: note surprise; 3: note onset; 4: metronome

% If you type 'stim' in the terminal, you will note that stim.condNames
% includes 'Listening' and 'Imagery' conditions. The code that follows
% selects only one of the conditions at a time
condIdx = 1; % Experimental condition to keep: 0: all conditions; 1: Listening; 2: Imagery

% Loading Stimulus data
stimFilename = [dataMainFolder,dataCNDSubfolder,'dataStim.mat'];
disp(['Loading stimulus data: ','dataStim.mat'])
load(stimFilename,'stim')
% Downsampling stim if necessary
if downFs < stim.fs
    stim = cndDownsample(stim,downFs);
end

% TRF
clear rAll rAllElec modelAll
figure('Position',[100,100,600,600]);
for sub = 1:nSubs
    % Loading preprocessed EEG
    neuralPreFilename = [dataMainFolder,dataCNDSubfolder,'pre_',neuralFilenames(sub).name];
    disp(['Loading preprocessed EEG data: pre_',neuralFilenames(sub).name])
    neural = importdata(neuralPreFilename); % it should contain only one variable (e.g., 'neural', 'eeg', 'meg')

    % Selecting feature of interest ('stimIdx' feature)
    stimFeature = stim;
    stimFeature.names = stimFeature.names{stimIdx};
    stimFeature.data = stimFeature.data(stimIdx,:); % envelope or word onset
    
    % Making sure that stim and neural data have the same length
    % The trial may end a few seconds after the end of the audio
    % e.g., the neural data may include the break between trials
    % It would be best to do this chunking at preprocessing, but let's
    % check here, just to be sure
    [stimFeature,neural] = cndCheckStimNeural(stimFeature,neural);
    
    % Standardise stim data (preserving the ratio between features)
    % This is thought for continuous signals e.g., speech envelope, neural
    stimFeature = cndNormalise(stimFeature);
    % Standardise neural data (preserving the ratio between channels)
    neural = cndNormalise(neural);
        
    % TRF crossvalidation - determining optimal regularisation parameter
    disp('Running mTRFcrossval')
    if any(unique(stim.condIdxs) == condIdx) % if valid condition
        [stats,t] = mTRFcrossval(stimFeature.data(stim.condIdxs==condIdx),neural.data(stim.condIdxs==condIdx),neural.fs,dirTRF,tmin,tmax,lambdas,'verbose',0);
    else % otherwise consider all conditions at once
        [stats,t] = mTRFcrossval(stimFeature.data,neural.data,neural.fs,dirTRF,tmin,tmax,lambdas,'verbose',0);    
    end
    
    % Calculating optimal lambda. Display and store results
    [maxR,bestLambda] = max(squeeze(mean(mean(stats.r,1),3)));
    disp(['r = ',num2str(maxR)])
    rAll(sub) = maxR;
    rAllElec(:,sub) = squeeze(mean(stats.r(:,bestLambda,:),1));
    
    % Fit TRF model with optimal regularisation parameter
    disp('Running mTRFtrain')
    model = mTRFtrain(stimFeature.data,neural.data,neural.fs,dirTRF,tmin,tmax,lambdas(bestLambda),'verbose',0);
    
    % Store TRF model
    modelAll(sub) = model;
    
    if dirTRF == 1
        mTRF_plotForwardTRF(neural,modelAll,rAllElec);
    elseif dirTRF == -1
        mTRF_plotBackwardTRF(neural,modelAll,rAllElec);
    end
    
    disp(['Mean r = ',num2str(mean(rAll))])
    
    drawnow;
end
