%% Load data
clear all; clc;
data_load = load('chunked_dla_tree.mat');
chunk_1 = data_load.chunk_1;
chunk_2 = data_load.chunk_2;
chunk_3 = data_load.chunk_3;
chunk_4 = data_load.chunk_4;
chunk_5 = data_load.chunk_5;

labs_1 = chunk_1(:, 11);
labs_2 = chunk_2(:, 11);
labs_3 = chunk_3(:, 11);
labs_4 = chunk_4(:, 11);
labs_5 = chunk_5(:, 11);
labs = [labs_1; labs_2; labs_3; labs_4; labs_5];

chunk_1 = chunk_1(:, 1:10);
chunk_2 = chunk_2(:, 1:10);
chunk_3 = chunk_3(:, 1:10);
chunk_4 = chunk_4(:, 1:10);
chunk_5 = chunk_5(:, 1:10);

data = [chunk_1; chunk_2; chunk_3; chunk_4; chunk_5];

%% Run phate and get kernel
[Y, diffOp, DiffOp_t] = phate(data, 'npca', 5, 'mds_method', 'cmds');
figure;scatter(Y(:, 1), Y(:, 2));
[axy, gxy] = alphakernel(data);

%% Construct graph and do gft
G_0 = gsp_graph(gxy);
G = gsp_compute_fourier_basis(G_0); % Clear G_0 if data gets big
G.coords = Y;
ft_labs = gsp_gft(G, labs);
figure;
subplot(1,2,1);gsp_plot_signal(G,labs);
subplot(1,2,2);gsp_plot_signal_spectral(G, ft_labs);

%% Smooth by gsp_design_heat i.e. Magic
tau = 100;
G_smoothed = gsp_design_heat(G, tau);
wave_coefs = gsp_filter_analysis(G, G_smoothed, labs);

figure;
gsp_plot_signal(G, wave_coefs);

