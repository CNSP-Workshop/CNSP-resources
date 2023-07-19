function stats = mTRFcvbanded(stim,resp,fs,map,tmin,tmax,lambda,grouping)

%mTRFcrossval mTRF Toolbox cross-validation function.
%   [R,P,MSE] = MTRFCVBANDED(STIM,RESP,FS,MAP,TMIN,TMAX,LAMBDA,grouping performs
%   leave-one-out cross-validation on the set of stimuli STIM and the
%   neural responses RESP for the range of ridge parameter values LAMBDA.
%   As a measure of performance, it returns the correlation coefficients R
%   between the predicted and original signals, the corresponding p-values
%   P and the mean squared errors MSE. Pass in MAP==1 to map in the forward
%   direction or MAP==-1 to map backwards. The sampling frequency FS should
%   be defined in Hertz and the time lags should be set in milliseconds
%   between TMIN and TMAX.
%
%   [...,PRED,MODEL] = MTRFCROSSVAL(...) also returns the predictions PRED
%   and the linear mapping functions MODEL.
%
%   Inputs:
%   stim   - set of stimuli [cell{1,trials}(time by features)]
%   resp   - set of neural responses [cell{1,trials}(time by channels)]
%   fs     - sampling frequency (Hz)
%   map    - mapping direction (forward==1, backward==-1)
%   tmin   - minimum time lag (ms)
%   tmax   - maximum time lag (ms)
%   lambda - ridge parameter values
%
%   Outputs:
%   r      - correlation coefficients
%   p      - p-values of the correlations
%   mse    - mean squared errors
%   pred   - prediction [MAP==1: cell{1,trials}(lambdas by time by chans),
%            MAP==-1: cell{1,trials}(lambdas by time by feats)]
%   model  - linear mapping function (MAP==1: trials by lambdas by feats by
%            lags by chans, MAP==-1: trials by lambdas by chans by lags by
%            feats)
%
%   See README for examples of use.
%
%   See also LAGGEN MTRFTRAIN MTRFPREDICT MTRFMULTICROSSVAL.

%   References:
%      [1] Crosse MC, Di Liberto GM, Bednar A, Lalor EC (2015) The
%          multivariate temporal response function (mTRF) toolbox: a MATLAB
%          toolbox for relating neural signals to continuous stimuli. Front
%          Hum Neurosci 10:604.

%   Author: Aaron Nidiffer
%   Lalor Lab, University of Rochester, Rochester, NY, USA
%   Email: edmundlalor@gmail.com
%   Website: http://lalorlab.net/
%   April 2014; Last revision: 31 May 2016


% lambda = [10.^(-3:12); 10.^(-1:10)];
% grouping = [1,1,1,1,1,2,2,2,2,2];
tikh=0;
nlambdas = length(lambda);
nbands = max(grouping);

% Define x and y
if tmin > tmax
    error('Value of TMIN must be < TMAX')
end
if map == 1
    x = stim;
    y = resp;
elseif map == -1
    x = resp;
    y = stim;
    [tmin,tmax] = deal(tmax,tmin);
else
    error('Value of MAP must be 1 (forward) or -1 (backward)')
end
clear stim resp

% Convert time lags to samples
tmin = floor(tmin/1e3*fs*map);
tmax = ceil(tmax/1e3*fs*map);

% Lambda matrix
lambdas = lambda';
for tt = 2:nbands
    lambdas = [repmat(lambdas,nlambdas,1) sort(repmat(lambdas(:,end),nlambdas,1))];
end

% Set up regularisation
dim1 = length(tmin:tmax);
dim2 = size(y{1},2);
model = zeros(numel(x),size(lambdas,1),dim1.*size(x{1},2)+nbands,dim2);
% M = eye(dim1,dim1);
% if tikh
%     d = 2*eye(dim1,dim1); d([1,end]) = 1;
%     u = [zeros(dim1,1),eye(dim1,dim1-1)];
%     l = [zeros(1,dim1);eye(dim1-1,dim1)];
%     M = d-u-l;
% end

% Training
 X_banded = cell(1,numel(x));
for tt = 1:numel(x) % Each trial
    fprintf('.')
    % Generate lag matrices for this trial
    for jj = 1:nbands % Each feature band
        X{jj} = [ones(size(x{tt}(:,1))),lagGen(x{tt}(:,grouping==jj),tmin:tmax)]; %%%%%%% Does the constant go here or in X_banded?
        M{jj} = eye(size(X{jj},2));
        X_banded{tt} = [X_banded{tt} ones(size(x{tt}(:,1))),lagGen(x{tt}(:,grouping==jj),tmin:tmax)];
    end
    
    % Banding
    XTX_banded = [];XT_banded = [];
    for jj = 1:nbands % Each feature band
        rX = [];
        for kk = 1:nbands % Each feature band
            rX = [rX X{jj}'*X{kk}];
        end
        XTX_banded = [XTX_banded; rX];
        XT_banded = [XT_banded; X{jj}'];
    end
    
    for ll = 1:size(lambdas,1)
        M_banded = [];
        for jj = 1:nbands % Each feature band
            rL = [];
            for kk = 1:nbands % Each feature band
                if jj==kk
                    rL = [rL M{jj}.*lambdas(ll,jj)];
                else
                    rL = [rL zeros(size(X{jj}'*X{kk}))];
                end
            end
            M_banded = [M_banded; rL];
        end
        
        % Calculate model for each lambda value
        model(tt,ll,:,:) = (XTX_banded+M_banded)\(XT_banded*y{tt});
    end
end
fprintf('\n')
% Testing
r = zeros(numel(x),size(lambdas,1),dim2);
p = zeros(numel(x),size(lambdas,1),dim2);
mse = zeros(numel(x),size(lambdas,1),dim2);
for tt = 1:numel(x)
    fprintf('.')
    pred = zeros(size(lambdas,1),size(y{tt},1),dim2);
    % Define training trials
    trials = 1:numel(x);
    trials(tt) = [];
    % Perform cross-validation for each lambda value
    for ll = 1:size(lambdas,1)
        % Calculate prediction
        pred(ll,:,:) = X_banded{tt}*squeeze(mean(model(trials,ll,:,:),1));
        % Calculate accuracy
        for kk = 1:dim2
            [r(tt,ll,kk),p(tt,ll,kk)] = corr(y{tt}(:,kk),squeeze(pred(ll,:,kk))');
            mse(tt,ll,kk) = mean((y{tt}(:,kk)-squeeze(pred(ll,:,kk))').^2);
        end
    end
end
fprintf('\n')
stats.r = r;
stats.err = mse;
stats.lambdas = lambdas;
end