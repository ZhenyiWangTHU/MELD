import numpy as np
from scipy.spatial.distance import cdist


def mnn_kernel(X, k, a, sample_idx=None, metric='euclidean', verbose=False):
    """
    Creates a kernel linking the k mutual nearest neighbors (MNN) across datasets
    and performs diffusion on this kernel using MAGIC to apply batch correction.

    Parameters
    ----------
    X : ndarray [n, p]
        2 dimensional input data array with n observations and p dimensions

    k : int
        Number of neighbors to use

    a : int
        Specifies alpha for the α-decaying kernel

    sample_idx : ndarray [n], optional, default: None
        1 dimensional array specifying the sample to which each observation in
        X belongs. If left empty, X is assumed to be one sample

    metric : string, optional, default: 'euclidean'
        reccomended values: 'eucliean' and 'cosine'
        Any metric from scipy.spatial.distance can be used
        Specifies distance metric for finding MNN

    Returns
    -------
    diff_op : ndarray [n, n]
        2 dimensional array diffusion operator created using a MNN kernel
    """

    if sample_idx is None:
        sample_idx = np.ones(len(X))

    samples = np.unique(sample_idx)

    K = np.zeros((len(X), len(X)))
    K[:] = np.nan

    # Build KNN kernel
    if verbose: print('Finding KNN...')
    for si in samples:
        X_i = X[sample_idx == si]            # get observations in sample i
        for sj in samples:
            X_j = X[sample_idx == sj]        # get observation in sample j
            pdx_ij = cdist(X_i, X_j, metric=metric) # pairwise distances
            kdx_ij = np.sort(pdx_ij, axis=1) # get kNN
            e_ij   = kdx_ij[:,k]             # dist to kNN
            pdx_ij = pdx_ij / e_ij[:, np.newaxis] # normalize
            k_ij   = np.exp(-1 * (pdx_ij ** a))  # apply α-decaying kernel np.exp(-1 * ( pdx ** a))
            K[sample_idx == si, :][:, sample_idx == sj] = k_ij # fill out values in K for NN from I -> J
            if si != sj:
                pdx_ji = pdx_ij.T # Repeat to find KNN from J -> I
                kdx_ji = np.sort(pdx_ji, axis=1)
                e_ji   = kdx_ji[:,k]
                pdx_ji = pdx_ji / e_ji[:, np.newaxis]
                k_ji = np.exp(-1 * (pdx_ji ** a))
                K[sample_idx == sj, :][:, sample_idx == si] = k_ji
    if verbose: print('Computing Operator...')
    K = K + K.T
    diff_deg = np.diag(np.sum(K,0)) # degrees
    diff_op = np.dot(np.diag(np.diag(diff_deg)**(-1)), K) # row stochastic ->
    if verbose: print('Done!')
    return diff_op
