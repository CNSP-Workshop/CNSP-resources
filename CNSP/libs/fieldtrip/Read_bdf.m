function [EEG, trigs] = Read_bdf(filename)

[dat] = openbdf(filename);

HeadLen = dat.Head.HeadLen;
NumChans = dat.Head.NS;
RecLen = dat.Head.SampleRate(1);
NRec = dat.Head.NRec;

fid = fopen(filename, 'r');

OneSec = RecLen*NumChans;

NREC = 0;

data = zeros(NumChans, NRec*RecLen);

while (fseek(fid,(HeadLen+(NREC+1)*OneSec*3),'bof') == 0)

    % From start of file seek a position (37120 + (second number - 1)*73728*3)

    fseek(fid,(HeadLen+NREC*OneSec*3),'bof');

    for i = 1:NumChans
        data(i,NREC*RecLen+(1:RecLen)) = fread(fid,RecLen,'bit24')';
    end
        
    NREC = NREC + 1;

end;

fclose(fid);

EEG = data(1:(NumChans-1),:);
trigs = data(NumChans,:);

% trigs = data(144,:);