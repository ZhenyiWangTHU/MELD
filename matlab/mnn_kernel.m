function [DiffOp, K] = mnn_kernel(data, sample_ind, npca, k, a, distfun)
% [DiffOp, K] = mnn_kernel(data, sample_ind, npca, k, a, distfun)
%
%   creates a kernel that in combination with MAGIC does batch correction
%
%   sample_ind are the sample indices

if ~exist('distfun','var')
    distfun = 'euclidean';
end

if isempty(sample_ind)
    sample_ind = ones(size(data,1),1); % sample_ind identifies each of multiple concatenated samples in a single matrix
end

uniq_samp = unique(sample_ind);
n_samp = length(uniq_samp);

if npca > 0
    M = svdpca(data, npca, 'random');
else
    M = data;
end

K = nan(size(data,1));
for I=1:n_samp
    I
    samp_I = uniq_samp(I);        % sample index at position I
    idx_I = sample_ind == samp_I; % logical index for obs with samp_ind
    MI = M(idx_I,:);              % slice reduce data matrix for in sample_I points
    for J=1:I
        samp_J = uniq_samp(J);
        idx_J = sample_ind == samp_J;
        MJ = M(idx_J,:);                 % slice reduce data matrix for in sample_J points
        PDXIJ = pdist2(MI, MJ, distfun); % distance from each point in sample_I to each in sample_J
        knnDSTIJ = sort(PDXIJ,2);        % get KNN
        epsilonIJ = knnDSTIJ(:,k);       % distance to KNN
        PDXIJ = bsxfun(@rdivide,PDXIJ,epsilonIJ); % normalize PDXIJ
        KIJ = exp(-PDXIJ.^a);            % apply α-decaying kernel
        K(idx_I, idx_J) = KIJ;           % fill out values in K for NN from I -> J
        if I~=J
            PDXJI = PDXIJ';         % Repeat to find KNN from J -> I
            knnDSTJI = sort(PDXJI,2);
            epsilonJI = knnDSTJI(:,k);
            PDXJI = bsxfun(@rdivide,PDXJI,epsilonJI);
            KJI = exp(-PDXJI.^a);
            K(idx_J, idx_I) = KJI;
        end
    end
end

disp 'computing operator'

K = K + K'; % MNN
DiffDeg = diag(sum(K,2)); % degrees
DiffOp = DiffDeg^(-1)*K; % row stochastic

disp 'done'