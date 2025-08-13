% Cognition and Natural Sensory Processing (CNSP) Initiative
% Preprocessing script
%
% This example script loads and preprocesses a publicly available dataset
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
% https://cnsp-resources.readthedocs.io/
% https://github.com/CNSP-Workshop/CNSP-resources
% https://cnspworkshop.net
% 
% Author: Giovanni M. Di Liberto, Aaron Nidiffer
% Copyright 2021 - Giovanni Di Liberto
%                  Nathaniel Zuk
%                  Michael Crosse
%                  Aaron Nidiffer
%                  Giorgia Cantisani
%                  (see license file for details)
% Last update: 14 September 2023

clear all
close all

run addPathDependencies.m

%% Parameters - Natural speech listening experiment
dataset = 'LalorNatSpeech';
datafolder = sprintf('../datasets/%s/dataCND/',dataset);

% subs = 1:19; % All subjects in the LalorNatSpeech dataset
subs = 10; % Our best subject for use in the tutorial
downFs = 64; % Hz. *** fs/downFs must be an integer value ***
reRefType = 'Avg'; % or 'Mastoids'
bandpassFilterRange = [1,8]; % filter frequency in Hz
                             % Indicate 0 to avoid running the low-pass
                             % or high-pass filters or both) e.g., [0,8]
                             % will apply only a low-pass filter at 8 Hz

if downFs < bandpassFilterRange(2)*2
    disp('Warning: Be careful. The low-pass filter should use a cut-off frequency smaller than downFs/2')
end

%% Preprocess EEG - Natural speech listening experiment
for sub = subs
    % Loading EEG data
    neuralFilename = sprintf('%sdataSub%d.mat',datafolder,sub);

    fprintf('Preprocessing EEG data, subject %d \n',sub)
    eeg = importdata(neuralFilename); % it should contain only one variable (e.g., 'neural', 'eeg', 'meg')

    eeg = cndNewOp(eeg,'Load'); % Saving the processing pipeline in the neural struct

    % Filtering - LPF (low-pass filter)
    if bandpassFilterRange(2) > 0
        hd = getLPFilt(eeg.fs,bandpassFilterRange(2));
        
        % A little coding trick - for loop vs cellfun
        if (0)
            % Filtering each trial/run with a for loop
            for ii = 1:length(eeg.data)
                eeg.data{ii} = filtfilthd(hd,eeg.data{ii});
            end
        else
            % Filtering each trial/run with a cellfun statement
            eeg.data = cellfun(@(x) filtfilthd(hd,x),eeg.data,'UniformOutput',false);
        end
        
        % Filtering external channels
        if isfield(eeg,'extChan')
            for extIdx = 1:length(eeg.extChan)
                eeg.extChan{extIdx}.data = cellfun(@(x) filtfilthd(hd,x),eeg.extChan{extIdx}.data,'UniformOutput',false);
            end
        end
        
        eeg = cndNewOp(eeg,'LPF');
    end
    
    % Downsampling EEG and external channels
    if downFs < eeg.fs
        eeg = cndDownsample(eeg,downFs);
    end
    
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
    
    % Replacing bad channels
    if isfield(eeg,'chanlocs')
        for tr = 1:length(eeg.data)
            eeg.data{tr} = removeBadChannels(eeg.data{tr}, eeg.chanlocs);
        end
    end
    
    % Re-referencing EEG data
    eeg = cndReref(eeg,reRefType);
    
    % Removing initial padding (specific to this dataset)
    if isfield(eeg,'paddingStartSample')
        for tr = 1:length(eeg.data)
            eeg.data{tr} = eeg.data{tr}(eeg.paddingStartSample,:);
            for extIdx = 1:length(eeg.extChan)
                eeg.extChan{extIdx}.data{tr} = eeg.extChan{extIdx}.data{tr}(1+eeg.paddingStartSample,:);
            end
        end
    end

    % Force type to double
    if ~isa(eeg.data{1},'double')
        for tr = 1:length(eeg.data)
            eeg.data{tr} = double(eeg.data{tr});

            for extIdx = 1:length(eeg.extChan)
                eeg.extChan{extIdx}.data{tr} = double(eeg.extChan{extIdx}.data{tr});
            end
        end
    end
    
    % Saving preprocessed data
    neuralPreFilename = sprintf('%spre_dataSub%d.mat',datafolder,sub);
    fprintf('Saving preprocessed EEG data: %s\n',neuralPreFilename)
    save(neuralPreFilename,'eeg')
end