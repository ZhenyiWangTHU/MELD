%% init
cd('~/Documents/GitHub/Blitz/matlab/runs')
out_base = '~/Dropbox/Phate/Sherm_spleen/figures/Dec15/'
mkdir(out_base);
addpath(genpath('~/Documents/GitHub/Blitz/'));
rseed = 7;

%% load data
data_dir = '~/Dropbox/Phate/Sherm_spleen/020617/';
sample1_LPS_KO = 'spleen1/';
sample2_CT_KO = 'spleen2/';
sample3_LPS_WT = 'spleen3/';
sample4_CT_WT = 'spleen4/';
%sdata_LPS_KO = load_10xData([data_dir sample1_LPS_KO]);
%sdata_CT_KO = load_10xData([data_dir sample2_CT_KO]);
sdata_LPS_WT = load_10xData([data_dir sample3_LPS_WT]);
sdata_CT_WT = load_10xData([data_dir sample4_CT_WT]);
%sample_names = {'sample1_LPS_KO', 'sample2_CT_KO', 'sample3_LPS_WT', 'sample4_CT_WT'};
sample_names = {'sample4_CT_WT', 'sample3_LPS_WT'};
%sdata_raw = merge_data({sdata_LPS_KO, sdata_CT_KO, sdata_LPS_WT, sdata_CT_WT}, sample_names);
sdata_raw = merge_data({sdata_CT_WT, sdata_LPS_WT}, sample_names);

%% to sdata
sdata = sdata_raw

%% library size hist
figure;
histogram(log10(sdata.library_size), 40);

%% lib size norm global
sdata = sdata.normalize_data_fix_zero();

%% sqrt transform
sdata.data = sqrt(sdata.data);

%% remove empty genes
genes_keep = sum(sdata.data) > 0;
sdata.data = sdata.data(:,genes_keep);
sdata.genes = sdata.genes(genes_keep);
sdata.mpg = sdata.mpg(genes_keep);
sdata.cpg = sdata.cpg(genes_keep);
sdata = sdata.recompute_name_channel_map()

%% remove means per sample
sdata_norm = sdata;
sdata_norm.data = subtract_means(sdata.data, sdata.samples);

%% PCA
npca = 100;
pc = svdpca(sdata_norm.data, npca, 'random');

%% plot PCA
figure;
c = sdata.samples;
scatter3(pc(:,1), pc(:,2), pc(:,3), 5, c, 'filled');
colormap(parula(length(unique(c))));
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
set(gca,'zticklabel',[]);
axis tight
title 'PCA'
xlabel 'PC1'
ylabel 'PC2'
zlabel 'PC3'
view([100 15]);
h = colorbar;
ylabel(h, 'Sample');
set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'PCA_3D_samples.tiff']);

%% MNN kernel
k = 3;
a = 15;
DiffOp = mnn_kernel_beta(pc, sdata.samples, [], k, a, 'euclidean', 0.5);

%% MNN kernel
% k = 3;
% a = 15;
% DiffOp = mnn_kernel_beta(pc, [], [], k, a, 'euclidean', 0.5);

%% MAGIC
tic;
t = 6;
disp 'powering operator'
DiffOp_t = DiffOp^t;
sdata_imputed = sdata;
disp 'imputing'
sdata_imputed.data = DiffOp_t * sdata.data;
toc

%% PCA after MAGIC
npca = 100;
pc_magic = svdpca(sdata_imputed.data, npca, 'random');

%% plot PCA after MAGIC 3D
figure;
c = sdata.samples;
scatter3(pc_magic(:,1), pc_magic(:,2), pc_magic(:,3), 5, c, 'filled');
colormap(parula(length(unique(c))));
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
set(gca,'zticklabel',[]);
axis tight
title 'MAGIC PCA'
xlabel 'PC1'
ylabel 'PC2'
zlabel 'PC3'
view([100 15]);
h = colorbar;
ylabel(h, 'Sample');
set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'MAGIC_PCA_3D_samples.tiff']);
%close

%% interpolate LPS treatment
t = 6;
lps_vec = sdata.samples - 1;
for I=1:t
    I
    lps_vec = DiffOp * lps_vec;
end

%% normalize vector cell numbers
lps_vec_norm = lps_vec;
lps_vec_norm = lps_vec_norm - min(lps_vec_norm);
lps_vec_norm = lps_vec_norm ./ max(lps_vec_norm);
non_lps_vec_norm = 1-lps_vec_norm;
lps_vec_norm = lps_vec_norm ./ sum(sdata.samples == 1);
non_lps_vec_norm = non_lps_vec_norm ./ sum(sdata.samples == 2);
sum_vec = sum(lps_vec_norm + non_lps_vec_norm,2);
lps_vec_norm = lps_vec_norm ./ sum_vec;
non_lps_vec_norm = non_lps_vec_norm ./ sum_vec;

%% plot PCA after MAGIC 3D colored by imputed LPS vector
figure;
c = lps_vec;
scatter3(pc_magic(:,1), pc_magic(:,2), pc_magic(:,3), 5, c, 'filled');
colormap(parula);
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
set(gca,'zticklabel',[]);
axis tight
title 'MAGIC PCA'
xlabel 'PC1'
ylabel 'PC2'
zlabel 'PC3'
view([100 15]);
h = colorbar;
ylabel(h, 'Sample');
set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'MAGIC_PCA_3D_samples_imputed_lps.tiff']);
%close

%% MMDS 2D on MAGIC
X = pc_magic;
X = squareform(pdist(X, 'euclidean'));
ndim = 2;
opt = statset('display', 'iter');
Y_start = randmds(X, ndim);
Y_mmds_magic_2D = mdscale(X, ndim, 'options', opt, 'start', Y_start, 'Criterion', 'metricstress');

%% plot MMDS MAGIC 2D
figure;
c = sdata.samples;
%c = t_vec;
scatter(Y_mmds_magic_2D(:,1), Y_mmds_magic_2D(:,2), 5, c, 'filled');
colormap(parula(length(unique(c))));
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
axis tight
%title 'MAGIC on PCA'
%xlabel 'PC1'
%ylabel 'PC2'
h = colorbar;
ylabel(h, 'LPS');
set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'MMDS_MAGIC_2D_samples.tiff']);
%close

%% plot MMDS MAGIC 2D imputed lps
figure;
c = lps_vec;
scatter(Y_mmds_magic_2D(:,1), Y_mmds_magic_2D(:,2), 5, c, 'filled');
colormap(parula);
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
axis tight
%title 'MAGIC on PCA'
%xlabel 'PC1'
%ylabel 'PC2'
h = colorbar;
ylabel(h, 'LPS interpolated');
set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'MMDS_MAGIC_2D_samples_imputed_lps.tiff']);
%close

%% plot MMDS MAGIC 2D imputed lps norm
figure;
c = lps_vec_norm;
scatter(Y_mmds_magic_2D(:,1), Y_mmds_magic_2D(:,2), 5, c, 'filled');
colormap(parula);
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
axis tight
%title 'MAGIC on PCA'
%xlabel 'PC1'
%ylabel 'PC2'
h = colorbar;
ylabel(h, 'LPS interpolated normalized');
%set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'MMDS_MAGIC_2D_samples_imputed_lps_norm.tiff']);
%close

%% PHATE with log distance
t = 6;
distfun_mds = 'euclidean';
DiffOp_t = DiffOp^t;
disp 'potential recovery'
DiffOp_t(DiffOp_t<=eps)=eps;
DiffPot = -log(DiffOp_t);
% DiffPot = sqrt(DiffOp_t); % Hellinger PHATE
npca = 100;
DiffPot_pca = svdpca(DiffPot, npca, 'random'); % to make pdist faster
D_DiffPot = squareform(pdist(DiffPot_pca, distfun_mds));

%% CMDS PHATE
ndim = 10;
Y_phate_cmds = randmds(D_DiffPot, ndim);

%% Phate CMDS 3D
figure;
c = lps_vec_norm;
scatter3(Y_phate_cmds(:,1), Y_phate_cmds(:,2), Y_phate_cmds(:,3), 5, c, 'filled');
colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
set(gca,'zticklabel',[]);
axis tight
%title 'CMDS PHATE'
%xlabel 'MDS1'
%ylabel 'MDS2'
%zlabel 'MDS3'
view([100 15]);
h = colorbar;
ylabel(h, 'LPS interpolated normalized');
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'CMDS_PHATE_3D_samples_lps_norm.tiff']);
%close

%% Metric MDS PHATE 2D
ndim = 2;
opt = statset('display', 'iter');
Y_start = randmds(D_DiffPot, ndim);
Y_phate_mmds = mdscale(D_DiffPot, ndim, 'options', opt, 'start', Y_start, 'Criterion', 'metricstress');

%% plot MMDS PHATE 2D
figure;
c = lps_vec_norm;
scatter(Y_phate_mmds(:,1), Y_phate_mmds(:,2), 5, c, 'filled');
colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
axis tight
title 'MMDS PHATE'
xlabel 'MDS1'
ylabel 'MDS2'
h = colorbar;
ylabel(h, 'LPS interpolated normalized');
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'MMDS_PHATE_2D_samples_hellinhger_lps_norm.tiff']);
%close

%% subplot color by gene
genes = {'TNF' 'IL1A' 'IL1B' 'IFNG'};
genes = intersect(genes, upper(sdata_imputed.genes));
nr = floor(sqrt(length(genes)));
nc = ceil(length(genes) / nr);
figure;
for I=1:length(genes)
    I
    c = get_channel_data(sdata_imputed, genes{I});
    subplot(nr, nc, I);
    scatter(Y_mmds_magic_2D(:,1), Y_mmds_magic_2D(:,2), 1, c, 'filled');
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    axis tight
    title(genes{I})
    axis off
    drawnow
end
set(gcf,'paperposition',[0 0 4*nc 3*nr]);
print('-dtiff',[out_base 'MMDS_MAGIC_2D_subplot_noax.tiff']);
%close

%% latent dim vs expression subplot
genes = {'TNF' 'IL1A' 'IL1B' 'IFNG'};
genes = intersect(genes, upper(sdata_imputed.genes));
nr = floor(sqrt(length(genes)));
nc = ceil(length(genes) / nr);
figure;
for I=1:length(genes)
    I
    c = get_channel_data(sdata_imputed, genes{I});
    subplot(nr, nc, I);
    scatter(lps_vec, c, 1, sdata.samples, 'filled');
    colormap(jet)
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    axis tight
    title(genes{I})
    if I==1
        xlabel 'lps imputed'
    end
    drawnow
end
set(gcf,'paperposition',[0 0 4*nc 3*nr]);
print('-dtiff',[out_base 'lps_imputed_vs_genes_samples.tiff']);
close

%% kNN DREMI of score vs all genes
x = lps_vec;
num_bin = 20;
num_grid = 60;
gene_set = sdata_imputed.genes;
mi = nan(length(gene_set),1);
dremi = nan(length(gene_set),1);
for I=1:length(gene_set)
    I
    y = gene_set{I}
    [mi(I), dremi(I)] = dremi_knn(sdata_imputed, x, y, 'num_grid', num_grid, 'num_bin', num_bin, 'k', 10, 'make_plots', false);
end

%% read CD genes
genes_file = '~/Dropbox/EMT_dropseq/gene_lists/gsea_cell_differentiation_markers.txt';
gene_set = read_gene_set(genes_file);
[LIA,LOCB] = ismember(lower(sdata_imputed.genes), lower(gene_set));
dremi(LIA)

%% entropy of LPS vector
lps_vec_entropy = sdata.samples - 1;
H = nan(16,1);
P = lps_vec_entropy ./ sum(lps_vec_entropy);
P = P(P>0);
H(1) = -sum(P .* log(P));
for I=2:length(H)
    I
    lps_vec_entropy = DiffOp * lps_vec_entropy;
    P = lps_vec_entropy ./ sum(lps_vec_entropy);
    %P = P(P>0);
    P(P==0) = eps;
    H(I) = -sum(P .* log(P));
end

%%
figure;
plot(0:length(H)-1, H, '*-');
xlabel 't'
set(gca,'xtick',0:length(H)-1)



