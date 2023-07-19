% This example script takes raw EEG data recorded with a BioSemi Active 2
% system, and saves it into a CND data structure.
% The script is compatible with the typical experiments involving
% continuous speech and music listening.
% 
% What can this script process? EEG experiments where participants listened
% to audio streams (e.g., speech and music). The script is written for .bdf
% data files. Each data file must correspond to a single experimental
% session. In a session, participants listened to audio segments, each
% corresponding to a single .wav audio file. A single audio segment is
% referred to as a 'trial'. In the script, please specify the trigger code
% for the audio onset. It is also possible to group trials into conditions
% (e.g., listening, imagery) based on that trigger code. For example,
% code 1-20 correspond to condition 1, audio 1-20
% code 21-40 correspond to condition 2, audio 1-20
%
% Note that this script assumes that each trial is run only once, without
% repetitions.
%
% If your experiment includes additional elements compared to
% what described above (e.g., behavioural data, actions, conditions),
% please modify this script and share it with the community here:
% https://github.com/CNSP-Workshop/CNSP-resources
%
% Authors: Giovanni Di Liberto
%          
% Trinity College Dublin
% July 2023
% BSD 3-Clause License

clear all

% First of all, load the channel location file. Here is the chanloc file
% for the standard 64 % channel cap for the BioSemi system
load('.\chanlocs64.mat')

% EEG setup (please adjust to your experiment)
fsEEG = 512;             % Recording frequency (Hz)
eegChannelsIdxs = 1:64;  % idx of EEG scalp channels
eegMastoidIdx = [65,66]; % idx of mastoid channels
eegOtherExt = 67:72;     % idx of other external channels

% Preprocessing parameters (please adjust to your experiment)
subs = 1:10;                  % Subjects to process

% Preprocessing parameters (Example experiment)
trigCode_audioStart = 1:42; % all trigger codes corresponding to the
                            % start of a trial
nAudioFiles = 42;           % number of audio files
nCond = 1;                  % number of conditions, where conditions have the same audio-material
                            % (e.g., listening vs. imagery;
                            %        audio-visual vs. audio;
                            %        speech vs. vocoded speech)
                            % Specify nCond=1 if different stimuli for
                            % different conditions.

% Paths
rawEEGPath = './rawNeural/';
rawAudioPath = './rawStimuli/';
dataCNDPath = './dataCND/';
mkdir(dataCNDPath)

% Get audio length
audioLengths = zeros(nAudioFiles,1);
for iiAudio = 1:nAudioFiles
    [xAudio,fsAudio] = audioread([rawAudioPath,'audio',num2str(iiAudio),'.wav']);
    audioLengths(iiAudio) = length(xAudio)/fsAudio; % seconds                                                  
end
                                                         %%%%%%%%%%%%%%                        audioLengths = audioLengths/2;
% Chunk and save EEG data
for iiSub = subs                  % for each subject
    clear eeg
    
    % Set bdf filename
    bdfFilename = convertCharsToStrings([rawEEGPath,'sub',num2str(iiSub),'.bdf']); % e.g., sub1.bdf
    % Load bdf
    [EEG,trigs] = Read_bdf(bdfFilename);
    
    % Preprocess trigger vector
%     trigs(trigs == max(trigs)) = min(trigs);
    trigs = trigs-min(trigs);
    trigs(trigs>256) = trigs(trigs>256)-min(trigs(trigs>256));
    
    % Triggers are usually steps. Keep only the onset
    % i.e., keep the positive changes in the derivative of trig
    trigs = [0,diff(trigs)];
    trigs(trigs<0) = 0;
    % Find all triggers (codes and time-sample)
    trialStartSamples = [];
    trigsSample = find(trigs ~= 0);
    trigsCode = trigs(trigsSample);
    % Keep triggers indicating the start of a trial
    idx2keep = ismember(trigsCode,trigCode_audioStart); 
    trigsCode = trigsCode(idx2keep);
    trigsSample = trigsSample(idx2keep);
    
    % Info for eeg structure
    neural.dataType = 'EEG';
    neural.deviceName = 'BioSemi ActiveTwo';
    neural.fs = fsEEG;
    neural.chanlocs = chanlocs;
    
    % Segment EEG based on trial length
    neural.data = cell(1,length(trigCode_audioStart));
    neural.extChan{1}.data = cell(1,length(trigCode_audioStart));
    neural.extChan{2}.data = cell(1,length(trigCode_audioStart));
    neural.extChan{1}.description = 'Mastoids';
    neural.extChan{2}.description = 'Other external channels'; % you can change this so that it fits your experiment
    
    for iiSegment = 1:length(trigCode_audioStart)
        % Calculating which audio file and condition were used in this segment
        iiAudio = mod(trigsCode(iiSegment)-1,nAudioFiles)+1; % e.g., trig 21 indicates audio 1 cond 2,
                                                         % when only 20 audio files are involved
        iiCond = floor((trigsCode(iiSegment)-1)/nAudioFiles)+1;

        % Calculating samples for the chunking
        stimStart = uint32(trigsSample(iiSegment));
        stimEnd = uint32(stimStart + audioLengths(iiAudio)*fsEEG);
        
        neural.data{iiSegment} = EEG(eegChannelsIdxs,stimStart:stimEnd)';
        neural.extChan{1}.data{iiSegment} = EEG(eegMastoidIdx,stimStart:stimEnd)'; % left and right mastoid channels
        neural.extChan{2}.data{iiSegment} = EEG(eegOtherExt,stimStart:stimEnd)';   % other external channels
    end

    disp(sprintf('\b.'))
    
    % Save eeg
    save([dataCNDPath,'./dataSub',num2str(iiSub),'.mat'], 'neural');
end

