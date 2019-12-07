
clear;
clc;
close all;


%-- Load colour schemes --------------------------------------------------%
addpath('cmap');
cm = load_cmap('YlGnBu',255);
cm_alt = cm;
load('inferno.mat');
cm = cm(40:end,:);
cm_b = cm;
cm_div = load_cmap('RdBu',200);
load('viridis.mat');



%%
%== STEP 1: Generate phantom (x_t) =======================================%
%   High resolution version of the distribution to be projected to coarse 
%   grid to generate x.
span_t = [10^-1.5,10^1.5;20,10^3]; % range of mobility and mass

phantom = Phantom('3',span_t);
x_t = phantom.x;
grid_t = phantom.grid;
nmax = max(x_t);
cmax = nmax;

%--  Generate x vector on coarser grid -----------------------------------%
n_x = [50,64]; % number of elements per dimension in x
    % [20,32]; % used for plotting projections of basis functions
    % [40,64]; % used in evaluating previous versions of regularization

grid_x = Grid([grid_t.span],...
    n_x,'logarithmic');
x0 = grid_x.project(grid_t.edges,x_t); % project into basis for x

figure(1);
phantom.plot;
colormap(gcf,[cm;1,1,1]);
caxis([0,cmax*(1+1/256)]);

hold on; % plots mg ridges of phantom
plot(log10(grid_t.edges{2}),...
    log10(phantom.mg_fun(grid_t.edges{2})),'w:');
hold off;



%%
%== STEP 2: Generate A matrix ============================================%
n_b = [14,50]; %[14,50]; %[17,35];
span_b = grid_t.span;
grid_b = Grid(span_b,...
    n_b,'logarithmic'); % grid for data

prop_pma = kernel.prop_pma;
[A_t,sp] = kernel.gen_A_grid(grid_b,grid_t,prop_pma,'Rm',3);
    % generate A matrix based on grid for x_t and b

% sp = kernel.grid2sp(...
%     prop_pma,grid_b,'Rm',3);
% A_alt = kernel.gen_A(sp,grid_b.elements(:,2),...
%     grid_t,prop_pma);

%%
disp('Transform to discretization in x...');
B = grid_x.rebase(grid_t); % evaluate matrix modifier to transform kernel
A = A_t*B; % equivalent to integration, rebases kernel to grid for x (instead of x_t)
A = sparse(A);
disp('Complete.');
disp(' ');

figure(2);
colormap(gcf,[cm;1,1,1]);
grid_x.plot2d_marg(x0,grid_t,x_t);
caxis([0,cmax*(1+1/256)]);



%%
%== STEP 3: Generate data ================================================%
b0 = A_t*x_t; % forward evaluate kernel


%-- Corrupt data with noise ----------------------------------------------%
b0(0<1e-10.*max(max(b0))) = 0; % zero very small values of b

Ntot = 1e5;
theta = 1/Ntot;
gamma = max(sqrt(theta.*b0)).*1e-4; % underlying Gaussian noise
Sigma = sqrt(theta.*b0+gamma^2); % sum up Poisson and Gaussian noise
Lb = sparse(1:grid_b.Ne,1:grid_b.Ne,1./Sigma,grid_b.Ne,grid_b.Ne);
rng(0);
epsilon = Sigma.*randn(size(b0));
b = sparse(b0+epsilon); % add noise
% b = max(b,0); % remove negative values
% b(b<1/Ntot) = 0; % remove negative and small values
b = max(round(b.*Ntot),0)./Ntot;

figure(5);
colormap(gcf,cm_b);
grid_b.plot2d_marg(b);

figure(20);
grid_b.plot2d_sweep(b,cm_b);



%% 
%== STEP 4: Perform inversions ===========================================%
run_inversions_g;
run_inversions_i;



%%
%== STEP 5: Visualize the results ========================================%
x_plot = out_tk1(1).x; % out_tk1(36).x;

figure(10);
colormap(gcf,[cm;1,1,1]);
grid_x.plot2d(x_plot); % ,grid_t,x_t);
caxis([0,cmax*(1+1/256)]);
colorbar;

figure(11);
ind = 20;
scl = max(max(abs(x_plot-x0)));
grid_x.plot2d(x_plot-x0);
colormap(cm_div);
caxis([-scl,scl]);

%{
figure(13);
grid_x.plot2d_sweep(x_plot,cm);
%}

figure(10);


%%
ind = 36;
x_plot = x_em; % out_tk1(ind).x;

figure(10);
colormap(gcf,[cm;1,1,1]);
grid_x.plot2d(x_plot); % ,grid_t,x_t);
caxis([0,cmax*(1+1/256)]);
colorbar;

Gpo_inv = (Lb_alt*A)'*(Lb_alt*A)+...
    out_tk1(ind).lambda^2.*(out_tk1(1).Lpr'*out_tk1(1).Lpr);
spo = sqrt(1./diag(Gpo_inv));
% Gpo = inv(Gpo_inv);
% spo = sqrt(max(diag(Gpo),1e-19));

figure(12);
colormap(gcf,cm_alt);
grid_x.plot2d(spo);
colorbar;

%%
ind = 35;
Lpr = out_tk1(1).Lpr;
Gpo_inv = (Lb*A)'*(Lb*A)+out_tk1(ind).lambda^2*(Lpr')*Lpr;
Gpo = inv(Gpo_inv);
spo = sqrt(diag(Gpo));
figure(35);
grid_x.plot2d(spo);
colormap(cm);
colorbar;

%%
% det_po = [];
% det_pr = [];
out = out_tk1;
Lpr = out(1).Lpr;
Lpr = Lpr./Lpr(1,1);

for kk=1:length(out)
%     kk
%     Gpo_inv = (Lb*A)'*(Lb*A)+out(kk).lambda^2*(Lpr')*Lpr;
%     Gpo = inv(Gpo_inv);
%     det_po(kk) = tools.logdet(Gpo);
%     Gpr = inv(out(kk).lambda^2*(Lpr')*Lpr);
%     det_pr(kk) = tools.logdet(Gpr);
    fit_b(kk) = norm(Lb*(A*out(kk).x-b));
    fit_pr(kk) = norm(Lpr*out(kk).x);
end
% B = 1/2.*(-(fit_pr+fit_b) -det_pr+det_po);
F = -1/2.*(fit_pr+fit_b);

loglog([out_tk1.lambda],[out_tk1.chi]);
hold on;
loglog([out_tk1.lambda],-F);
hold off;

%%
%-- Bar plot of results --------------------------------------------------%
figure(30);
chi_names = fieldnames(chi);
chi_vals = zeros(length(chi_names),1);
for ii=1:length(chi_names)
    chi_vals(ii) = chi.(chi_names{ii});
end

bar(chi_vals);
% ylim([0,20]);
% ylim([0,100]);
set(gca,'xticklabel',chi_names);


%%
%{
%-- Bar plot of times ----------------------------------------------------%
figure(40);
t_names = fieldnames(t);
t_vals = zeros(length(t_names),1);
for ii=1:length(t_names)
    t_vals(ii) = mean(t.(t_names{ii}),2);
end

bar(t_vals);
set(gca,'xticklabel',t_names);
set(gca,'yscale','log');



%%
%-- Plot marginal distributions ------------------------------------------%
figure(31);
clf;
dim = 2;

grid_t.plot_marginal(x_t,dim);
grid_x.plot_marginal(...
    {x_Tk1,x_init,x_MART,x_Two,x_TwoMH},dim,x0);



%%
%-- Plot conditional distributions ---------------------------------------%
figure(31);
clf;
dim = 2;
ind_plot = 25;

grid_x.plot_conditional(...
    {x0,x_Tk1,x_init,x_MART,x_Two,x_TwoMH},dim,ind_plot,x0);
%}


