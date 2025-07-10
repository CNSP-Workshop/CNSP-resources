% Cognition and Natural Sensory Processing (CNSP) open-science initiative
% Forward TRF script
%
% This script loads and analyses EEG data that was preprocessed
% using CNSP2025_EEGpreprocessing.m
%
% CNSP-Workshop 2025
% https://cnspworkshop.net
% Author: Giovanni M. Di Liberto
% Copyright 2025 - Giovanni Di Liberto
%                  CNSP initiative
%                  (see license file for details)
% Last update: 13 May 2025

clear
addpath ..\libs\cnsp_utils
run addPathDependencies.m
eeglab
close

% Parameters - Natural speech listening experiment
datasetName = 'LalorNatSpeech'; % this is the name of the dataset folder (which must be inside ../datasets/)
downFs = 64; % Hz; make sure that this is the same set in the preprocessing script
reRefType = 'Mastoids'; % re-referencing is a rapid preprocessing that
                % we prefer performing here, allowing us to explore different
                % options without re-running the (costly) preprocessing
                % script. Please feel free to augment our scripts by adding
                % other types of re-referencing.
freqBands2analyse = [5]; % 1: delta, 2: theta, 3: alpha, 4: beta, 5: 1-8Hz; 6: broadband
                             % see getFreqParams function

% Fixed parameters
dataMainFolder = '../datasets/';
dataCNDSubfolder = '/dataCND/';
eegFilenames = dir([dataMainFolder,datasetName,dataCNDSubfolder,'dataSub*.mat']);
nSubs = length(eegFilenames);

% TRF hyperparameters
dirTRF = 1; % Forward TRF model
tmin = -100;
tmax = 600;
lambdas = [1e-4,1e-3,1e-2,1e-1,1e0,1e1,1e2,1e3,1e4];
stimIdx = 1;  % Dataset specific: feature index
              % Here, 1: Envelope; 2: word onset
condIdx = 1; % consider adding a condIdx variable for handling different
             % conditions. This specific dataset only had one condition.

for freqBand = freqBands2analyse
    [freqBandName,bandpassFilterRange] = getFreqParams(freqBand);

    % Loading Stim data (if same dataStim for all participants)
    stimFilename = [dataMainFolder,datasetName,dataCNDSubfolder,'dataStim.mat'];
    if exist(stimFilename)
        disp(['Loading stimulus data: ','dataStim.mat'])
        load(stimFilename,'stim')
        if downFs < stim.fs
            stim = cndDownsample(stim,downFs);
        end
    end

    % TRF
    clear rAll modelAll rAllElec
    figure;
    for sub = 1:nSubs
        % Loading preprocessed EEG
        eegPreFilename = [dataMainFolder,datasetName,dataCNDSubfolder,freqBandName,'/pre_',eegFilenames(sub).name];
        disp(['Loading preprocessed EEG data: pre_',eegFilenames(sub).name])
        load(eegPreFilename,'eeg')
        
        % Loading Stimulus data (if one dataStim per participant)
        if ~exist(stimFilename)
            subIdx = regexp(eegFilenames(sub).name, '\d+', 'match'); % finding corresponding index
            subIdx = str2double(subIdx{1});
            stimFilename = [dataMainFolder,datasetName,dataCNDSubfolder,'dataStim',num2str(subIdx),'.mat'];
            disp(['Loading stimulus data: ','dataStim',num2str(subIdx),'.mat'])
            load(stimFilename,'stim')
            % Downsampling stim if necessary
            if downFs < stim.fs
                stim = cndDownsample(stim,downFs);
            end
        end
    
        % Re-referencing EEG data
        eeg = cndReref(eeg,reRefType);
        
        % Selecting feature of interest
        stimFeature = stim;
        stimFeature.data = stimFeature.data(stimIdx,:);
        
        % Selecting condition of interest
        trials2keep = stimFeature.condIdxs == condIdx;
        stimFeature.data = stimFeature.data(:,trials2keep);
        eeg.data = eeg.data(trials2keep);
        
        % Making sure that stim and neural data have the same length
        if eeg.fs ~= stimFeature.fs
            disp('Error: EEG and STIM have different sampling frequency')
            return
        end
        if length(eeg.data) ~= length(stimFeature.data)
            disp('Error: EEG.data and STIM.data have different number of trials')
            return
        end
        for tr = 1:length(stimFeature.data)
            envLen = size(stimFeature.data{tr},1);
            eegLen = size(eeg.data{tr},1);
            minLen = min(envLen,eegLen);
            stimFeature.data{tr} = double(stimFeature.data{tr}(1:minLen,:));
            eeg.data{tr} = double(eeg.data{tr}(1:minLen,:));
        end
        
        % TRF - Compute model weights
        disp('Running mTRFcrossval')
        [stats,t] = mTRFcrossval(stimFeature.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas,'verbose',0);
        [maxR,bestLambda] = max(squeeze(mean(mean(stats.r,1),3)));
        disp(['r = ',num2str(maxR)])
        rAll(sub) = maxR;
        rAllElec(:,sub) = squeeze(mean(stats.r(:,bestLambda,:),1));
    
        disp('Running mTRFtrain')
        model = mTRFtrain(stimFeature.data,eeg.data,eeg.fs,dirTRF,tmin,tmax,lambdas(bestLambda),'method','Tikhonov','verbose',0);
        
        modelAll(sub) = model;
        
        mTRF_plotForwardTRF(eeg,modelAll,rAllElec);
    
        disp(['Mean r = ',num2str(mean(rAll))])
        
        drawnow;
    end
    % Saving output figure and data
    mkdir("resultFigures/"+freqBandName)
    chanlocs = eeg.chanlocs;
    save("./resultFigures/"+freqBandName+"/TRF_nSub"+nSubs+"_condIdx"+condIdx+"_stimIdx"+stimIdx+".mat",'modelAll','rAll','rAllElec','chanlocs')
    savefig("./resultFigures/"+freqBandName+"/TRF_nSub"+nSubs+"_condType"+condIdx+"_stimIdx"+stimIdx+".fig")
end
