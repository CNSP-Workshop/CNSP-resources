% Cognition and Natural Sensory Processing (CNSP) Workshop
% Example 3 - CCA
%
% This example script loads and preprocesses a publicly available dataset
% (you can use any of the dataset in the CNSP resources). Then, the script
% runs a CCA analysis, evaluated with correlation in CC space as well as
% with a match-vs-mismatch classification score.
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
dataMainFolder = '../datasets/LalorNatSpeech/';
% dataMainFolder = '../datasets/LalorNatSpeechReverse/';
dataCNDSubfolder = 'dataCND/';

reRefType = 'Avg'; % or 'Mastoids'
bandpassFilterRange = [0.01,16]; % Hz (indicate 0 to avoid running the low-pass
                          % or high-pass filters or both)
                          % e.g., [0,8] will apply only a low-pass filter
                          % at 8 Hz
downFs = 32; % Hz. *** fs/downFs must be an integer value ***
             % Note that CCA is slower than the mTRF. As such, we will need
             % a heavier downsampling

neuralFilenames = dir([dataMainFolder,dataCNDSubfolder,'dataSub*.mat']);
nSubs = length(neuralFilenames);

%% Preprocess EEG - Natural speech listening experiment
% Same preprocessing as in examples 1 and 2
% This time, we downsample the data to 32 Hz
% Also, CCA has less tight constraints in terms of filtering than TRF
% analyses. As such, we can use wider frequency ranges or even no filters
% at all

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
    neuralPreFilename = [dataMainFolder,dataCNDSubfolder,'preCCA_',neuralFilenames(sub).name];
    disp(['Saving preprocessed EEG data: pre_',neuralFilenames(sub).name])
    save(neuralPreFilename,'neural')
end

%% Canonical Correlation Analysis
% Note: CCA tends to overfit more easily than the mTRF. So, the parameter
% tuning is a very important process. It is essential that the user
% understands what the parameters mean and do, and how to carry out the
% tuning.

% Note2: Dimensionality reduction relies on PCA in this example. DSS/JD
% would be a more appropriate approach, if available.

% Stim parameters
stimIdx = 1; % 1: env; 2: word onset

% Loading Stimulus data
stimFilename = [dataMainFolder,dataCNDSubfolder,'dataStim.mat'];
disp(['Loading stimulus data: ','dataStim.mat'])
load(stimFilename,'stim')
% Downsampling stim if necessary
if downFs < stim.fs, stim = cndDownsample(stim,downFs); end

% CCA parameters
tmin = -1500; % ms - search window
tmax = 1500;  % ms
shifts = (floor(tmin/1000*stim.fs):4:ceil(tmax/1000*stim.fs));

tminModel = 0; % ms - model (time-lags) window
tmaxModel = 300;  % ms
shiftsModel = (floor(tminModel/1000*stim.fs):1:ceil(tmaxModel/1000*stim.fs));

ncomp = 1; % 0: all components
nPCS = 16; % PCs to keep when preprocessing the stim and neural data
          % (Same for stim and neural data here)

% Eval+uation parameters
windowSize = 30; % window-size for the match-vs-mismatch decoding evaluation
                % (seconds)
    
clear rCCallSub accMMall
figure('Position',[100,100,600,600]);
for sub = 1:nSubs
    % Loading preprocessed EEG
%     neuralPreFilename = [dataMainFolder,dataCNDSubfolder,'pre_',neuralFilenames(sub).name];
%     disp(['Loading preprocessed EEG data: pre_',neuralFilenames(sub).name])
    neuralPreFilename = [dataMainFolder,dataCNDSubfolder,'preCCA_',neuralFilenames(sub).name];
    disp(['Loading preprocessed EEG data: preCCA_',neuralFilenames(sub).name])
    neural = importdata(neuralPreFilename); % it should contain only one variable (e.g., 'neural', 'eeg', 'meg')
    
    % Downsampling neural if necessary
    if downFs < neural.fs, neural = cndDownsample(neural,downFs); end
%     for tr = 1:length(neural.data)
%         neural.data{tr} = double(neural.data{tr});
%     end

    clear AA BB RR iBest rAll
    for testTr = 1 %:length(neural.data)
        trainTr = setdiff(1:length(neural.data),testTr);

        % Stim - smoothing filters and dimensionality reduction
        xx = stim.data(stimIdx,trainTr);
        xx = dili_ccaDataPrep(xx,nPCS); % it is also possible to specify a
                                      % different set of smoothing filters
        % Neural data - smoothing filters and dimensionality reduction
        yy = neural.data(trainTr);         
        yy = dili_ccaDataPrep(yy,nPCS);
%         yy = dili_ccaDataPrep_shifts(yy,nPCS,shiftsModel);

        % cca crossval, match-vs-mismatch version (mm)
        [AA,BB,RR,~,accMM] = ...
            nt_cca_crossvalidate_mm(xx,yy,shifts,windowSize*stim.fs,ncomp); 
        % RR: nPCs x shifts x trials
        rAll(:,:,testTr) = mean(RR,3);
        
        % Storing tuning curve (first CC)
        rCCallSub(:,sub) = rAll(1,:)';
        
        % Storing MM classification
        accMMall(:,sub) = accMM;
        
        % Plot tuning curve (one line per subject)
        subplot(2,1,1)
        shiftsMs = shifts/stim.fs * 1000;
        plot(shiftsMs,rCCallSub,'.-','LineWidth',1.5,'MarkerSize',20)
        xticks(tmin:300:tmax)
        xlabel('Time-lag (ms)')
        ylabel('Correlation (r)')
%         legend(num2str((1:sub)'))
        title('Corr for first CC pair')
        grid on
        run prepExport.m
        
        subplot(2,1,2)
        shiftsMs = shifts/stim.fs * 1000;
        plot(shiftsMs,accMMall,'.-','LineWidth',1.5,'MarkerSize',20)
        xticks(tmin:300:tmax)
        xlabel('Time-lag (ms)')
        ylabel('Classification accuracy')
%         legend(num2str((1:sub)'))
        title(['Match-vs-mismatch classification; win = ',num2str(windowSize),'s'])
        grid on
        run prepExport.m
        
        % Get optimal parameters
        % TODO
        
        % Match-vs-mismatch on test trial
        % TODO
        
        drawnow;
    end
end

