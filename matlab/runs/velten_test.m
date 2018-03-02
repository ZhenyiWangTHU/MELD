%% init
cd('~/Documents/GitHub/Blitz/matlab/runs')
addpath(genpath('~/Documents/GitHub/Blitz/'));
rseed = 7;

%% load data 1
file_dir = '~/Dropbox/velten_et_al_2017/';
file_transcriptomics_raw_1 = 'GSE75478_transcriptomics_raw_filtered_I1.csv';
file_facs_1 = 'GSE75478_transcriptomics_facs_indeces_filtered_I1.csv';

% read transcripts 1
fid = fopen([file_dir file_transcriptomics_raw_1]);
line1 = strsplit(fgetl(fid),',');
ncol = length(line1);
C = textscan(fid, ['%s' repmat('%f',1,ncol-1)],'Delimiter',',');
fclose(fid);
cell_ids_trans1 = regexprep(line1(2:end), '"', '');
M_trans1 = cell2mat(C(2:end))';
gene_names_trans1 = regexprep(C{1}, '"', '');

% read facs 1
fid = fopen([file_dir file_facs_1]);
line1 = strsplit(fgetl(fid),',');
ncol = length(line1);
C = textscan(fid, ['%s' repmat('%f',1,ncol-1)],'Delimiter',',');
fclose(fid);
cell_ids_facs1 = regexprep(line1(2:end), '"', '');
M_facs1 = cell2mat(C(2:end))';
gene_names_facs1 = regexprep(C{1}, '"', '');

[C,IA,IB] = intersect(cell_ids_trans1, cell_ids_facs1);
cell_ids1 = C;
M_trans1 = M_trans1(IA,:);
M_facs1 = M_facs1(IB,:);

%% to sdata
sdata1 = scRNA_data('data_matrix', M_trans1, 'cell_names', cell_ids1, 'gene_names', gene_names_trans1);
sdata = sdata1;

%% library size hist
figure;
histogram(log10(sdata.library_size), 40);

%% lib size norm global
sdata = sdata.normalize_data_fix_zero();

%% sqrt transform
%sdata.data = sdata.data.^(1/4);
sdata.data = log(sdata.data + 0.1);

%% PCA
npca = 100;
pc = svdpca(sdata.data, npca, 'random');

%% plot PCA
figure;
%c = sdata.samples;
scatter3(pc(:,1), pc(:,2), pc(:,3), 10, 'k', 'filled');
axis tight
title 'PCA'
xlabel 'PC1'
ylabel 'PC2'
zlabel 'PC3'

%% operator
k = 3;
a = 15;
DiffOp = mnn_kernel(pc, [], [], k, a);

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

%% plot PCA MAGIC
figure;
c = get_channel_data(sdata_imputed, 'CD34 (ENSG00000174059)');
scatter3(pc_magic(:,1), pc_magic(:,2), pc_magic(:,3), 10, c, 'filled');
axis tight
title 'PCA MAGIC'
xlabel 'PC1'
ylabel 'PC2'
zlabel 'PC3'

%% MMDS 2D on MAGIC
X = pc_magic;
X = squareform(pdist(X, 'euclidean'));
ndim = 2;
opt = statset('display', 'iter');
Y_start = randmds(X, ndim);
Y_mmds_magic_2D = mdscale(X, ndim, 'options', opt, 'start', Y_start, 'Criterion', 'metricstress');

%% plot MMDS MAGIC 2D
figure;
c = get_channel_data(sdata_imputed, 'CD33 (ENSG00000105383)');
scatter(Y_mmds_magic_2D(:,1), Y_mmds_magic_2D(:,2), 10, c, 'filled');
colormap(parula)
set(gca,'xticklabel',[]);
set(gca,'yticklabel',[]);
axis tight
%title 'MAGIC on PCA'
%xlabel 'PC1'
%ylabel 'PC2'
%h = colorbar;
%ylabel(h, 'Latent developmental time');
%set(h,'yticklabel',[]);



