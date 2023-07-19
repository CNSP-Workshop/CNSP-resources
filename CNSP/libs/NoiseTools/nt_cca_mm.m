function [D,E,R]=nt_cca_mm(x,y,ssize,flipflag)
%[D,E,R]=nt_cca_match_mm3(x,y,ssize) - calculate metrics for match-mismatch task
%
%  D: d-prime 
%  E: error rate
%  R: correlation coefficient over entire trial
%
%  x,y: data as trial arrays
%  ssize: samples, segment size [default: all]
%  flipflag: if true flip mismatched segments timewise [default false]

if nargin<2; error('!'); end
if nargin<3; ssize=[]; end
if nargin<4||isempty(flipflag); flipflag=0; end

if ssize ~= round(ssize); error('!'); end

% clip all trials to same size multiple of wsize
n=size(x{1},1); % min size?
for iTrial=1:numel(x)
    if size(x{iTrial}) ~= size(y{iTrial}); error('!'); end
    n=min(n,size(x{iTrial},1));
end
if isempty(ssize); ssize=n; end
n=ssize*floor(n/ssize); % reduce to multiple of wsize
if n<1; error('!'); end
for iTrial=1:numel(x)
    x{iTrial}=nt_demean(x{iTrial}(1:n,:)); % clip trials to new length
    y{iTrial}=nt_demean(y{iTrial}(1:n,:));
end
nsegments=n/ssize;
ntrials=numel(x);

if 0 % scramble (sanity check, should yield approx d-prime==0 and error == 50%)
    for iTrial=1:ntrials
        y{iTrial}=y{1+mod(iTrial+5,ntrials)};
        %disp([iTrial, 1+mod(iTrial+5,ntrials)]);
    end
end

% CCA
shifts=[0]; xvalidate=1;
[AA,BB,RR]=nt_cca_crossvalidate(x,y,shifts,xvalidate);
R=mean(RR,3);

for iTrial=1:ntrials
    
    % calculate model on data excluding this trial
    others=setdiff(1:ntrials,iTrial);
    
    % CCs
    xx=nt_mmat(x(others),AA{iTrial});
    yy=nt_mmat(y(others),BB{iTrial});
    ncomp=size(xx{1},2);

    % cut into segments
    X=zeros(ssize,ncomp,numel(others),nsegments);
    Y=zeros(ssize,ncomp,numel(others),nsegments);
    for iTrial2=1:numel(others)
        for iWindow=1:nsegments
            start=(iWindow-1)*ssize;
            X(:,:,iTrial2,iWindow)=nt_normcol(nt_demean(xx{iTrial2}(start+(1:ssize),:))); % all mean 0 norm 1
            Y(:,:,iTrial2,iWindow)=nt_normcol(nt_demean(yy{iTrial2}(start+(1:ssize),:)));
        end
    end
    
    % Euclidean distance between EEG and envelope segments
    
    % match
    D_match=sqrt(mean((X-Y).^2));
    sz=size(D_match); D_match=reshape(D_match,sz(2:end));
    D_match=D_match(:,:)'; % trials X comps
    
    % mismatch
    D_mismatch=sqrt(mean((X-circshift(Y,1,3)).^2));
    sz=size(D_mismatch); D_mismatch=reshape(D_mismatch,sz(2:end));
    D_mismatch=D_mismatch(:,:)'; % trials X comps
    
    c0=nt_cov(D_match)/size(D_mismatch,1);
    c1=nt_cov(D_mismatch)/size(D_match,1);
    [todss,pwr0,pwr1]=nt_dss0(c0,c1);
    if mean(D_match*todss(:,1))<0; todss=-todss; end
    
    DD_match=D_match*todss(:,1);
    DD_mismatch=D_mismatch*todss(:,1);
    
    dprime(iTrial)=abs(mean(DD_match)-mean(DD_mismatch)) / std([DD_match-mean(DD_match); DD_mismatch-mean(DD_mismatch)]);    

    %{
    We now have a CCA solution and a JD transform calculated
    on other trials. 
    
    We apply them to segments of this trial.
    %}
    
    % apply same CCA transform:
    xx_x=nt_mmat(x{iTrial},AA{iTrial});
    yy_x=nt_mmat(y{iTrial},BB{iTrial});
    % yy_x=nt_mmat(y{1+mod(iTrial,ntrials)},BB{iTrial}); % scramble
    
    %figure(1); plot([xx_x,yy_x]); pause
    
    % cut CCs into segments
    X_x=zeros(ssize,ncomp,nsegments);
    Y_x=zeros(ssize,ncomp,nsegments);
    for iWindow=1:nsegments
        start=(iWindow-1)*ssize;
        X_x(:,:,iWindow)=nt_normcol(nt_demean(xx_x(start+(1:ssize),:)));
        Y_x(:,:,iWindow)=nt_normcol(nt_demean(yy_x(start+(1:ssize),:)));
    end
    
    % Euclidean distance for matched segments
    D_match_x=zeros(nsegments,ncomp);
    for iWindow=1:nsegments
        D_match_x(iWindow,:)=sqrt( mean((X_x(:,:,iWindow)-Y_x(:,:,iWindow)).^2) );
    end        
    
    % average Euclidean distance for mismatched segments
    D_mismatch_x=zeros(nsegments,ncomp);
    for iWindow=1:nsegments
        X_all_others=X(:,:,:); % all segments of all other trials
        if flipflag;
            X_all_others=X_all_others(end:-1:1,:,:);
        end
        tmp=bsxfun(@minus,X_all_others,Y_x(:,:,iWindow));
        d = sqrt(mean((tmp).^2));
        D_mismatch_x(iWindow,:)=mean(d,3);
    end
    
%      figure(1); clf;  
%      for k=1:6; subplot (3,2,k); plot([D_match_x(:,k),D_mismatch_x(:,k)]); end
    if 1    
        D_match_x=D_match_x*todss(:,1);
        D_mismatch_x=D_mismatch_x*todss(:,1);
    else
        D_match_x=D_match_x(:,1);
        D_mismatch_x=D_mismatch_x(:,1);
    end
    
%      figure(2); clf;
%      plot([D_match_x,D_mismatch_x])
%      pause
    
    err(iTrial)=numel(find(D_mismatch_x<D_match_x))/nsegments;
    %disp(err(iTrial))
end

D=mean(dprime);
E=mean(err);


