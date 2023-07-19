function cnd = cndDownsample(cnd,downFs)
%CNDDOWNSAMPLE Downsamples the neural data (e.g., EEG) in CND format.
%   CND = CNDDOWNSAMPLE(CND,TYPE) downsamples the contant of a CND data
%      structure. For time-series of impulses (e.g., word-onset vector)
%      the function does its best to preserve all impulses, if that fits
%      the reduced sampling rate. Note that a time-series of impulses 
%      need to strictly contain impulses i.e., each impulse must be 
%      preceded and followed by zero values.
%
%   CNDREREF returns the CND structure after re-referencing the data
%       'cnd'       -- neural data in the Continuous-event Neural Data
%                      format (CND)
%       'downFs'    -- downsampling frequency. Note that fs/downFs must be
%                      an integer value.
%
%   Author: Giovanni Di Liberto
%   Last update: 19 July 2023
%   Copyright 2021 Di Liberto Lab, Trinity College Dublin

    if isempty(cnd) || isempty(cnd.data)
        disp('The CND structure is empty or not a cell array')
        return
    elseif ~iscell(cnd.data)
        disp('The CND.data structure is not a cell array')
        return
    end
    
    % Validate input parameters
    validateparamin(cnd)
    
    if downFs == cnd.fs
        disp("The stimulus is already sampled at " + downFs + " Hz")
        return
    end

    if mod(cnd.fs,downFs) ~= 0
        disp('Error: fs/downFs must be an integer value! Continuing without downsampling')
        return
    end
    
    % Downsampling each trial/run of the EEG data
%     cnd.data = cellfun(@(x) downsample(x,cnd.fs/downFs),cnd.data,'UniformOutput',false);
    
    for ii = 1:size(cnd.data,1)
    for jj = 1:size(cnd.data,2)
        x = cnd.data{ii,jj};
        nonZeroIdxs = find(x);
        if ~isempty(nonZeroIdxs)
            if (abs(x(nonZeroIdxs(2:end-1)-1))+abs(x(nonZeroIdxs(2:end-1)+1))) == 0 % if all impulses are surrounded by zeros
                isOnsetVector = 1;
            else 
                isOnsetVector = 0;
            end
        else
            isOnsetVector = 0; % run usual downsample if only two onsets.
                               % This should be changed for particular cases involving only one or two impulses
        end
        
        % Downsampling
        if isOnsetVector
            downX = zeros(round(size(x,1)/2),size(x,2));
            downX(round(nonZeroIdxs/2)) = x(nonZeroIdxs);
            cnd.data{ii,jj} = downX;
        else % run typcal downsample
            cnd.data{ii,jj} = downsample(x,cnd.fs/downFs);
        end
    end
    end
    
    % Downsampling each trial/run of the external channels
    if isfield(cnd,'extChan')
        for extIdx = 1:length(cnd.extChan)
            cnd.extChan{extIdx}.data = cellfun(@(x) downsample(x,cnd.fs/downFs),cnd.extChan{extIdx}.data,'UniformOutput',false);
        end
    end
    
    if isfield(cnd,'paddingStartSample')
        cnd.paddingStartSample = round(cnd.paddingStartSample / (cnd.fs/downFs));
    end

    % Updating fs value after the downsampling is successful
    cnd.originalFs = cnd.fs;
    cnd.fs = downFs;
    
    cnd = cndNewOp(cnd,"Downsampling from fs = "+cnd.originalFs+" to downFs = "+cnd.fs);
end


function validateparamin(cnd)
%VALIDATEPARAMIN  Validate input parameters.
%   VALIDATEPARAMIN(CND) validates the input parameters
%   of the main function.

    if isfield(cnd,'extChan')
        for ii = 1:length(cnd.extChan)
            if length(cnd.data) ~= length(cnd.extChan{ii}.data)
                error('External channels and main data have different number of elements (trials or runs)')
            end
        end
    end
end
