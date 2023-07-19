% eeg2cnd_LalorRevSpeech.m
% Script to convert the LalorLab Natural Speech dataset into
% the Continuous-events Neural Data format (CND)
%
% See the CND documentation for details on the format. I suggest looking
% into the example datasets first.
%
% About the data format. In brief:
% a single file is saved for data that is shared across all subjects. This
% file contains a variable 'stim' including, for example, stimulus features
% such as the speech envelope.
%
% A single file per subject contains the subject-specific data, e.g.,
% EEG and EMG signals. If the experiment was grouped into trials or runs,
% the data variable will be grouped in the same way by using cell arrays.
% The trial order is the same as in the 'stim' variable (so the same order
% across participants), and it will include a variable indicating the
% original presentation order for each subject.
%
%
% Example for the case of an audio-book listening experiment
%
% Key structures and variables:
%
% *** dataStim.mat: Information and data that is common across subjects
% stim.fs: Stim sampling frequency (same across all stim features)
% stim.data(1,:): Speech envelope for each trial
% stim.data(2,:): A second feature
%
% *** dataSub.mat: Subject-specific data. Here, this is the EEG signal
% eeg.fs: EEG sampling frequency
% eeg.data: cell array with the EEG signal for each run
% eeg.chanlocs: channel location information
% eeg.extChan{1}.data: EEG external mastoid electrodes (e.g., used for
%                      re-referencing the EEG signal)
% emg.data: This could be another stream for emg data
% acc.data: This could be a stream with accelerometric data
% eyetracking.data
% 
% 
% CNSP-Workshop 2021
% https://cnspworkshop.net
% Author: Giovanni M. Di Liberto
% Copyright 2021 - Giovanni Di Liberto
%                  Nathaniel Zuk
%                  Michael Crosse
%                  Aaron Nidiffer
%                  (see license file for details)
% Last update: 28 July 2021
%

% Parameters that are fixed for this dataset
subs = 1:10;                % Subjects to include
nRuns = 20;                 % Number of runs to include per subject
folderEvent = '../LalorNatSpeech/Stimuli/'; % This could be an external stimulus (speech
                            % perception experiment) or other events, such
                            % as a continuous action (speech production)
folderEEG = './EEG/';       % EEG data folder
folderCND = './dataCND/';   % Data in CEN format

load('chanlocs128.mat')

if ~exist(folderCND,'dir'), mkdir(folderCND); end

%% Converting EEG to the CND format
% CND: Continuous-events Neural Data format
disp('Preparing subject-specific data file')
for sub = subs
    disp(sprintf('\b.'))
    
    clear eeg
    eeg.dataType = 'EEG';
    eeg.deviceName = 'BioSemi';
    eeg.origTrialPosition = 1:nRuns; % Trial position in the original
                                     % presentation order
    for run = 1:nRuns
        % Load EEG data run
        load([folderEEG, 'Subject', num2str(sub), '\Subject', num2str(sub), '_Run', num2str(run), '.mat'],...
             'eegData','fs','mastoids')
         
        % Checking if sampling frequency is consistent with the first run
        if run == 1
            eeg.fs = fs;
        elseif eeg.fs ~= fs
            disp(['Error 1: The sampling frequency for run ', num2str(run), ' is inconsistent with run 1'])
            disp('         Please make sure that all runs have the same sampling frequency before running this script.')
            return
        end
        eeg.data{run} = eegData;             % Main EEG data
        eeg.extChan{1}.data{run} = mastoids; % External channels (mastoids)
    end
    eeg.extChan{1}.description = 'Mastoids';
    eeg.chanlocs = chanlocs;
    save([folderCND, 'dataSub', num2str(sub), '.mat'],'eeg')
end

%% Preprocessing Stimulus and conversion to CND
disp('Preparing stimulus data file')
clear stim % Stimulus features data (same for all participants). If trials
           % were shuffled, then they would have to be sorted back in the
           % subject-specific structures (e.g., 'eeg'). The presentation
           % order will be preserved in an additional variable.
for run = 1:nRuns
    disp(sprintf('\b.'))
    
    stim.names = {'Speech Envelope Vectors','Word Onset Vectors'};
    stim.stimIdxs = 1:nRuns; % Stimulus idxs corresponding to each element
                            % (run) in the eeg cell array
    stim.condIdxs = ones(1,nRuns);
    stim.condNames = {'Listening'};
    stim.fs = 128; % it was hard coded
    
    % Speech envelope
    load([folderEvent, 'Envelopes\audio', num2str(run), '_128Hz.mat'],'env')         
    stimIdx = 1;
    stim.data{stimIdx,run} = flip(env);
    
    % Word onset vector for content words
    load([folderEvent, 'Text\Run', num2str(run), '.mat'],'offset_time','onset_time','sentence_boundaries','wordVec')         
    stimIdx = 2;
    wordOn = zeros(size(env)); % creating the word onset vector
    wordOnIdxs = round(onset_time*stim.fs) + 1;
                % resampling. Also, time zero corresponds to sample 1
    wordOn(wordOnIdxs) = 1;
    stim.data{stimIdx,run} = flip(wordOn); clear wordOn
    stim.name = 'word onset vectors';
    
    % Other unprocessed data
    load([folderEvent, 'Text\Run', num2str(run), '.mat'],'offset_time','onset_time','sentence_boundaries','wordVec')         
    unprocessedWord2Vec.data{run}.offset_time = offset_time;
    unprocessedWord2Vec.data{run}.onset_time = onset_time;
    unprocessedWord2Vec.data{run}.sentence_boundaries = sentence_boundaries;
    unprocessedWord2Vec.data{run}.wordVec = wordVec;
    unprocessedWord2Vec.note = 'This information corresponds to the audio-book. Hence, whatever vector is build based on this information should be time-reversed to match this experiment';
    unprocessedWord2Vec.name = 'word2VecInfo';
end
save([folderCND, 'dataStim.mat'],'stim','unprocessedWord2Vec')

disp('Done!')

