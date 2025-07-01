% Cognition and Natural Sensory Processing (CNSP) open-science initiative
% EEG multi-band preprocessing
% The same script would run with other kinds of data (e.g., MEG, fNIRS).
% Some variable names and terminal information should be changed from EEG
% to your type of data. 
%
% CNSP-Workshop 2025
% https://cnspworkshop.net
% Author: Giovanni M. Di Liberto
% Copyright 2025 - Giovanni Di Liberto
%                  CNSP initiative
%                  (see license file for details)
% Last update: 13 May 2025

clear
close all

addpath ..\libs\cnsp_utils
run addPathDependencies.m
eeglab
close

% Parameters - Natural speech listening experiment
% *** In principle, the following three variables are the only ones that
% you should modify, unless you want to explore different frequency bands
% or you have particular preprocessing requirements
datasetName = 'LalorNatSpeech'; % this is the name of the dataset folder (which must be inside ../datasets/)
downFs = 64; % Hz. *** fs/downFs must be an integer value ***

% Other parameters
dataMainFolder = '../datasets/';
dataCNDSubfolder = '/dataCND/';
eegFilenames = dir([dataMainFolder,datasetName,dataCNDSubfolder,'dataSub*.mat']);
nSubs = length(eegFilenames);
freqBands2preprocess = 1:6; % 1: delta, 2: theta, 3: alpha, 4: beta, 5: 1-8Hz; 6: broadband
                             % see getFreqParams function

for sub = 1:nSubs
    % Loading EEG data
    eegFilename = [dataMainFolder,datasetName,dataCNDSubfolder,eegFilenames(sub).name];
    disp(['Loading EEG data: ',eegFilenames(sub).name])
    eegOrig = importdata(eegFilename); % this should contain only one variable (e.g., 'eeg', 'meg', 'fNIRS', 'gsr')

    for freqBand = freqBands2preprocess
        disp("Processing participant #"+sub+"; freq #"+freqBand)
        
        [freqBandName,bandpassFilterRange] = getFreqParams(freqBand);
        mkdir([dataMainFolder,datasetName,dataCNDSubfolder,freqBandName])
    
        if downFs < bandpassFilterRange(2)*2
            disp('Warning: The low-pass filter should use a cut-off frequency smaller than downFs/2')
        end

        eeg = eegOrig;

        % Filtering - LPF (low-pass filter)
        if bandpassFilterRange(2) > 0
            hd = getLPFilt(eeg.fs,bandpassFilterRange(2));
            
            % Filtering each trial/run with a cellfun statement
            eeg.data = cellfun(@(x) filtfilthd(hd,x),eeg.data,'UniformOutput',false);
            
            % Filtering external channels
            if isfield(eeg,'extChan')
                for extIdx = 1:length(eeg.extChan)
                    eeg.extChan{extIdx}.data = cellfun(@(x) filtfilthd(hd,x),eeg.extChan{extIdx}.data,'UniformOutput',false);
                end
            end
            
            eeg = cndNewOp(eeg,'LPF');
        end
        
        % Downsampling EEG and external channels
        eeg = cndDownsample(eeg,downFs);
        eeg = cndNewOp(eeg,'downsample');

        % Filtering - HPF (high-pass filter)
        if bandpassFilterRange(1) > 0 
            hd = getHPFilt(eeg.fs,bandpassFilterRange(1));
            
            % Filtering EEG data
            eeg.data = cellfun(@(x) filtfilthd(hd,x),eeg.data,'UniformOutput',false);
            
            % Filtering external channels
            if isfield(eeg,'extChan')
                for extIdx = 1:length(eeg.extChan)
                    eeg.extChan{extIdx}.data = cellfun(@(x) filtfilthd(hd,x),eeg.extChan{extIdx}.data,'UniformOutput',false);
                end  
            end
            
            eeg = cndNewOp(eeg,'HPF');
        end
        
        % Removing initial padding (specific to this dataset)
        if isfield(eeg,'paddingStartSample')
            for tr = 1:length(eeg.data)
                eeg.data{tr} = eeg.data{tr}((1+eeg.paddingStartSample):end,:);
                for extIdx = 1:length(eeg.extChan)
                    eeg.extChan{extIdx}.data{tr} = eeg.extChan{extIdx}.data{tr}((1+eeg.paddingStartSample):end,:);
                end
            end
            eeg = cndNewOp(eeg,'PaddingRemoval');
        end
        
        % Replacing bad channels
        if isfield(eeg,'chanlocs')
            for tr = 1:length(eeg.data)
                eeg.data{tr} = removeBadChannels(eeg.data{tr}, eeg.chanlocs, [], 3, 3);
            end
            eeg = cndNewOp(eeg,'BadChannelInterp');
        end
    
        % Saving preprocessed data
        eegPreFilename = [dataMainFolder,datasetName,dataCNDSubfolder,freqBandName,'/pre_',eegFilenames(sub).name];
        disp(['Saving preprocessed EEG data: pre_',eegFilenames(sub).name])
        save(eegPreFilename,'eeg')

        clear eeg
    end

    clear eegOrig
end
