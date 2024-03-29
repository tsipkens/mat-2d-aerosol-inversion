
% GEN_PMA_DMA  Evaluate kernel/transfer functions for PMA-DMA.
%  This function applies to miscellaneous PMA-DMA setpoints. 
%  The kernel.gen_pma_dma_grid function is preferred for computional
%  reasions. As such, this function should only be used when the data does
%  not adhere to a reasonable grid. 
% 
%  A = kernel.gen_pma_dma(SP,D_STAR,GRID_I) evaluates the transfer function
%  for the PMA setpoints specified by SP and the DMA setpoints specified by 
%  D_STAR. The kernel is evaluated by integrating the transfer function
%  over the elements in GRID_I. This require the same numder of entries in
%  SP and D_STAR. 
%  Please refer to the get_setpoint(...) function in tfer_pma folder for
%  more details on generating the SP struture.
% 
%  A = kernel.gen_pma_dma(SP,D_STAR,GRID_I,PROP_PMA) specifies a
%  pre-computed PMA property data structure. If not given, the function
%  uses the defaults of kernel.prop_pma(...).
% 
%  A = kernel.gen_pma_dma(SP,D_STAR,GRID_I,PROP_PMA,PROP_DMA) specifies a
%  pre-computed DMA property data structure. 
%  
%  ------------------------------------------------------------------------
% 
%  NOTE: Cell arrays are used for Omega_mat and Lambda_mat in order to 
%  allow for the use of sparse matrices, which is necessary to 
%  store information on higher resolutions grids (such as those 
%  used for phantoms).
% 
%  AUTHOR: Timothy Sipkens, 2020-02-04

function A = gen_pma_dma(sp, d_star, grid_i, prop_pma, prop_dma)

% If not given, import default properties of PMA, 
% as selected by prop_pma function.
if ~exist('prop_pma','var'); prop_pma = []; end
if isempty(prop_pma); prop_pma = kernel.prop_pma; end

if length(sp)~=length(d_star); error('Setpoint / d_star mismatch.'); end

if ~exist('prop_dma','var'); prop_dma = []; end

    
%-- Parse measurement set points (b) -------------------------------------%
n_b = length(sp); % length of data vector


%-- Generate grid for intergration ---------------------------------------%
n_i = grid_i.ne;
N_i = grid_i.Ne; % length of integration vector

r = grid_i.elements;
m = r(:,1);
d = r(:,2);


%-- Start evaluate kernel ------------------------------------------------%
tools.textheader('Computing PMA-DMA kernel');

%== Evaluate particle charging fractions =================================%
z_vec = (1:3)';
f_z = sparse(kernel.tfer_charge(d.*1e-9,z_vec)); % get fraction charged for d
n_z = length(z_vec);


%== STEP 1: Evaluate DMA transfer function ===============================%
%   Note: The DMA transfer function is 1D (only a function of mobility),
%   which is exploited to speed evaluation. The results is 1 by 3 cell, 
%   with one entry per charge state.
disp(' Computing DMA contribution:');
Omega_mat = cell(1,n_z); % pre-allocate for speed, one cell entry per charge state
tools.textbar([0, n_z]);
for kk=1:n_z
    Omega_mat{kk} = kernel.tfer_dma( ...
        d_star' .* 1e-9, ...
        grid_i.edges{2}' .* 1e-9, ...
        z_vec(kk), ...
        prop_dma);
    
    Omega_mat{kk}(Omega_mat{kk}<(1e-7.*max(max(Omega_mat{kk})))) = 0;
        % remove numerical noise in kernel
    
    [~,jj] = max(d==grid_i.edges{2},[],2);
    Omega_mat{kk} = Omega_mat{kk}(:,jj);
        % repeat transfer function for repeated mass setpoint
    
    tools.textbar([kk, n_z]);
end
disp(' Complete.');
disp(' ');


%== STEP 2: Evaluate PMA transfer function ===============================%
disp(' Computing PMA contribution:');
tools.textbar([0, n_z]); % initiate textbar
Lambda_mat = cell(1,n_z); % pre-allocate for speed
    % one cell entry per charge state
for kk=1:n_z % loop over the charge state
    % Evaluate PMA transfer function.
    Lambda_mat{kk} = kernel.tfer_pma(...
        sp, m' .* 1e-18,...
        d' .* 1e-9, z_vec(kk), prop_pma)';
            % PMA transfer function

    tools.textbar([kk, n_z]);
end
disp(' Complete.');
disp(' ');


%== SETP 3: Combine to compile kernel ====================================%
disp(' Compiling kernel ...');
K = sparse(n_b,N_i);
for kk=1:n_z
    K = K+f_z(z_vec(kk),:).*... % charging contribution
        Lambda_mat{kk}(:,:).*... % PMA contribution
        Omega_mat{kk}(:,:); % DMA contribution
end
tools.textdone();  % print orange DONE

dr_log = grid_i.dr; % area of integral elements in [logm,logd]T space
A = bsxfun(@times,K,dr_log'); % multiply kernel by element area
A = sparse(A); % exploit sparse structure

tools.textheader();


end



