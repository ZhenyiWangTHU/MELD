%% init
out_base = '~/Dropbox/noonan/figures/nov28/example_blitz/'
mkdir(out_base);
addpath(genpath('~/git_projects/Blitz/'));
rseed = 7;

%% load data
data_dir = '~/Dropbox/noonan/data/';
%sample_p2 = 'p2/';
sample_p3 = 'p3/';
sample_rm3 = 'rm3/';
%sample_rm4 = 'rm4/';
%sample_rm7 = 'rm7/';
%sdata_p2 = load_10xData([data_dir sample_p2]);
sdata_p3 = load_10xData([data_dir sample_p3]);
sdata_rm3 = load_10xData([data_dir sample_rm3]);
%sdata_rm4 = load_10xData([data_dir sample_rm4]);
%sdata_rm7 = load_10xData([data_dir sample_rm7]);
sample_names = {'p3', 'rm3'};
sdata_raw = merge_data({sdata_p3, sdata_rm3}, sample_names);

%% to sdata
sdata = sdata_raw

%% library size hist
figure;
histogram(log10(sdata.library_size), 40);

%% lib size norm global
sdata = sdata.normalize_data_fix_zero();

%% sqrt transform
sdata.data = sqrt(sdata.data);

%% filter by hemoglobin (Hba-a1)
x = get_channel_data(sdata, 'Hba-a1');
figure;
histogram(x);
th = 7;
cells_keep = x < th;
sdata.data = sdata.data(cells_keep,:);
sdata.cells = sdata.cells(cells_keep);
sdata.library_size = sdata.library_size(cells_keep);
sdata.samples = sdata.samples(cells_keep);
x = get_channel_data(sdata, 'Hba-a1');
figure;
histogram(x);

%% remove empty genes
genes_keep = sum(sdata.data) > 0;
sdata.data = sdata.data(:,genes_keep);
sdata.genes = sdata.genes(genes_keep);
sdata.mpg = sdata.mpg(genes_keep);
sdata.cpg = sdata.cpg(genes_keep);
sdata = sdata.recompute_name_channel_map()

%% PCA
npca = 100;
pc = svdpca(sdata.data, npca, 'random');

%% plot PCA
figure;
c = sdata.samples;
scatter3(pc(:,1), pc(:,2), pc(:,3), 5, c, 'filled');
colormap(jet)
%colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
set(gca,'zticklabel',[]);
axis tight
%title 'PCA'
%xlabel 'PC1'
%ylabel 'PC2'
%zlabel 'PC3'
view([100 15]);
%h = colorbar;
%ylabel(h, 'Time');
%set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'PCA_3D_samples.tiff']);
%close

%% MNN kernel
k = 3;
a = 15;
DiffOp = mnn_kernel(pc, sdata.samples, [], k, a);

%% MAGIC
tic;
t = 12;
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
%c = t_vec;
scatter3(pc_magic(:,1), pc_magic(:,2), pc_magic(:,3), 5, c, 'filled');
colormap(jet)
%colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
set(gca,'zticklabel',[]);
axis tight
%title 'PCA after MAGIC'
%xlabel 'PC1'
%ylabel 'PC2'
%zlabel 'PC3'
view([100 15]);
%h = colorbar;
%ylabel(h, 'Latent developmental time');
%set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'PCA_MAGIC_3D_samples.tiff']);
%close

%% MAGIC on random projection
tic;
[B, W1] = random_projection(sdata.data, 100);
t = 12;
%B_MAGIC = DiffOp^t * B;
B_magic = B;
for I=1:t
    I
    B_magic = DiffOp * B_magic;
end
% project B back to original space
sdata_imputed_random = sdata;
sdata_imputed_random.data = B_magic * W1';
% do PCA on projection
X = bsxfun(@minus, B_magic, mean(B_magic));
[U,~,~] = svd(X','econ');
pc_magic_random = X * U;
toc

%% plot PCA after MAGIC on random projection
figure;
c = sdata.samples;
%c = t_vec;
scatter3(pc_magic_random(:,1), pc_magic_random(:,2), pc_magic_random(:,3), 5, c, 'filled');
colormap(jet)
%colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
set(gca,'zticklabel',[]);
axis tight
%title 'PCA after MAGIC'
%xlabel 'PC1'
%ylabel 'PC2'
%zlabel 'PC3'
view([100 15]);
%h = colorbar;
%ylabel(h, 'Latent developmental time');
%set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'PCA_MAGIC_random_3D_samples.tiff']);
%close

%% interpolate time
t = 12;
t_vec = sdata.samples - 1;
for I=1:t
    I
    t_vec = DiffOp * t_vec;
end

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
colormap(jet)
%colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
axis tight
%title 'MAGIC on PCA'
%xlabel 'PC1'
%ylabel 'PC2'
%h = colorbar;
%ylabel(h, 'Latent developmental time');
%set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'MMDS_MAGIC_2D_samples.tiff']);
%close

%% subplot color by gene
genes = {'CHD8' 'SCN2A' 'ARID1B' 'NRXN1' 'SYNGAP1' 'DYRK1A' 'CHD2' 'ANK2' 'KDM5B' 'ADNP' 'POGZ' ...
    'SUV420H1' 'SHANK2' 'TBR1' 'GRIN2B' 'DSCAM' 'KMT2C' 'PTEN' 'SHANK3' 'TCF7L2' 'TRIP12' 'SETD5' ...
    'TNRC6B' 'ASH1L' 'CUL3' 'KATNAL2' 'WAC' 'NCKAP1'};
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

%% latent time vs expression subplot
genes = {'CHD8' 'SCN2A' 'ARID1B' 'NRXN1' 'SYNGAP1' 'DYRK1A' 'CHD2' 'ANK2' 'KDM5B' 'ADNP' 'POGZ' ...
    'SUV420H1' 'SHANK2' 'TBR1' 'GRIN2B' 'DSCAM' 'KMT2C' 'PTEN' 'SHANK3' 'TCF7L2' 'TRIP12' 'SETD5' ...
    'TNRC6B' 'ASH1L' 'CUL3' 'KATNAL2' 'WAC' 'NCKAP1'};
genes = intersect(genes, upper(sdata_imputed.genes));
nr = floor(sqrt(length(genes)));
nc = ceil(length(genes) / nr);
figure;
for I=1:length(genes)
    I
    c = get_channel_data(sdata_imputed, genes{I});
    subplot(nr, nc, I);
    scatter(t_vec, c, 1, sdata.samples, 'filled');
    colormap(jet)
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    axis tight
    title(genes{I})
    if I==1
        xlabel 'latent developmental time'
    end
    drawnow
end
set(gcf,'paperposition',[0 0 4*nc 3*nr]);
print('-dtiff',[out_base 'latent_time_vs_genes_samples.tiff']);
close

%% PHATE with Hellinger distance
t = 12;
distfun_mds = 'euclidean';
DiffOp_t = DiffOp^t;
disp 'potential recovery'
% DiffOp_t(DiffOp_t<=eps)=eps;
% DiffPot = -log(DiffOp_t);
DiffPot = sqrt(DiffOp_t); % Hellinger PHATE
npca = 100;
DiffPot_pca = svdpca(DiffPot, npca, 'random'); % to make pdist faster
D_DiffPot = squareform(pdist(DiffPot_pca, distfun_mds));

%% CMDS PHATE
ndim = 10;
Y_phate_cmds = randmds(D_DiffPot, ndim);

%% Phate CMDS 3D
figure;
c = sdata.samples;
%c = t_vec;
scatter3(Y_phate_cmds(:,1), Y_phate_cmds(:,2), Y_phate_cmds(:,3), 5, c, 'filled');
colormap(jet)
%colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
set(gca,'zticklabel',[]);
axis tight
%title 'CMDS PHATE'
%xlabel 'MDS1'
%ylabel 'MDS2'
%zlabel 'MDS3'
view([100 15]);
%h = colorbar;
%ylabel(h, 'Time');
%set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'CMDS_PHATE_3D_samples.tiff']);
%close

%% Metric MDS PHATE 2D
ndim = 2;
opt = statset('display', 'iter');
Y_start = randmds(D_DiffPot, ndim);
Y_phate_mmds = mdscale(D_DiffPot, ndim, 'options', opt, 'start', Y_start, 'Criterion', 'metricstress');

%% plot MMDS PHATE 2D
figure;
c = sdata.samples;
%c = t_vec;
scatter(Y_phate_mmds(:,1), Y_phate_mmds(:,2), 5, c, 'filled');
colormap(jet)
%colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
axis tight
%title 'MMDS PHATE'
%xlabel 'MDS1'
%ylabel 'MDS2'
%h = colorbar;
%ylabel(h, 'Time');
%set(h,'yticklabel',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base 'MMDS_PHATE_2D_samples.tiff']);
%close

%% subplot color by gene
genes = {'CHD8' 'SCN2A' 'ARID1B' 'NRXN1' 'SYNGAP1' 'DYRK1A' 'CHD2' 'ANK2' 'KDM5B' 'ADNP' 'POGZ' ...
    'SUV420H1' 'SHANK2' 'TBR1' 'GRIN2B' 'DSCAM' 'KMT2C' 'PTEN' 'SHANK3' 'TCF7L2' 'TRIP12' 'SETD5' ...
    'TNRC6B' 'ASH1L' 'CUL3' 'KATNAL2' 'WAC' 'NCKAP1'};
genes = intersect(genes, upper(sdata_imputed.genes));
nr = floor(sqrt(length(genes)));
nc = ceil(length(genes) / nr);
figure;
for I=1:length(genes)
    I
    c = get_channel_data(sdata_imputed, genes{I});
    subplot(nr, nc, I);
    scatter(Y_phate_mmds(:,1), Y_phate_mmds(:,2), 1, c, 'filled');
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    axis tight
    title(genes{I})
    axis off
    drawnow
end
set(gcf,'paperposition',[0 0 4*nc 3*nr]);
print('-dtiff',[out_base 'MMDS_PHATE_2D_subplot_noax.tiff']);
%close

