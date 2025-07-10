function [freqBandName,bandpassFilterRange] = getFreqParams(freqBand)
    if freqBand == 1
        freqBandName = 'delta';
        bandpassFilterRange = [0.5,4];
    elseif freqBand == 2
        freqBandName = 'theta';
        bandpassFilterRange = [4,8];
    elseif freqBand == 3
        freqBandName = 'alpha';
        bandpassFilterRange = [8,12];
    elseif freqBand == 4
        freqBandName = 'beta';
        bandpassFilterRange = [12,30];
    elseif freqBand == 5
        freqBandName = '1-8Hz';
        bandpassFilterRange = [1,8]; % used in many previous studies
    elseif freqBand == 6
        freqBandName = 'broadband';
        bandpassFilterRange = [0.5,30];
    end    
end
