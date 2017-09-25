clear
clc
close all hidden

addpath('signal');
addpath('estimation');

random_seed = round(sum(1e6 * clock()));
random_stream = RandStream('mt19937ar','Seed',random_seed);
RandStream.setGlobalStream(random_stream);

%% Load data.
main_folder = '/home/sms/diffusion_in_wood/';
file_paths = {  [main_folder '170912/27 0-250/frap.mat'], ...
                [main_folder '170912/27 0-250/frap_001.mat'], ...
                [main_folder '170912/27 0-250/frap_002.mat'], ...
                [main_folder '170912/27 0-250/frap_003.mat'], ...
                [main_folder '170912/27 0-250/frap_004.mat'], ...
                [main_folder '170912/6-2 0-250/frap.mat'], ...
                [main_folder '170912/6-2 0-250/frap_001.mat'], ...
                [main_folder '170912/6-2 0-250/frap_002.mat'], ...
                [main_folder '170912/6-2 0-250/frap_003.mat'], ...
                [main_folder '170912/6-2 0-250/frap_004.mat'], ...
                [main_folder '170912/GFP 0-250/frap.mat'], ...
                [main_folder '170912/GFP 0-250/frap_001.mat'], ...
                [main_folder '170912/GFP 0-250/frap_002.mat'], ...
                [main_folder '170912/GFP 0-250/frap_003.mat'], ...
                [main_folder '170912/GFP 0-250/frap_004.mat'] }';
% file_paths = {  [main_folder '170913/6 native/frap_001.mat'], ...
%                 [main_folder '170913/6 native/frap_002.mat'], ...
%                 [main_folder '170913/6 native/frap_003.mat'], ...
%                 [main_folder '170913/6 native/frap_004.mat'], ...
%                 [main_folder '170913/6 native/frap_005.mat'], ...
%                 [main_folder '170913/6 steam exp/frap_001.mat'], ...
%                 [main_folder '170913/6 steam exp/frap_002.mat'], ...
%                 [main_folder '170913/6 steam exp/frap_003.mat'], ...
%                 [main_folder '170913/6 steam exp/frap_004.mat'], ...
%                 [main_folder '170913/6 steam exp/frap_005.mat'], ...
%                 [main_folder '170913/27 native/frap_001.mat'], ...
%                 [main_folder '170913/27 native/frap_002.mat'], ...
%                 [main_folder '170913/27 native/frap_003.mat'], ...
%                 [main_folder '170913/27 native/frap_004.mat'], ...
%                 [main_folder '170913/27 native/frap_005.mat'], ...
%                 [main_folder '170913/27 steam exp/frap_001.mat'], ...
%                 [main_folder '170913/27 steam exp/frap_002.mat'], ...
%                 [main_folder '170913/27 steam exp/frap_003.mat'], ...
%                 [main_folder '170913/27 steam exp/frap_004.mat'], ...
%                 [main_folder '170913/27 steam exp/frap_005.mat'], ...
%                 [main_folder '170913/GFP native/frap_001.mat'], ...
%                 [main_folder '170913/GFP native/frap_002.mat'], ...
%                 [main_folder '170913/GFP native/frap_003.mat'], ...
%                 [main_folder '170913/GFP native/frap_004.mat'], ...
%                 [main_folder '170913/GFP native/frap_005.mat'], ...
%                 [main_folder '170913/GFP steam exp/frap_006.mat'], ...
%                 [main_folder '170913/GFP steam exp/frap_007.mat'], ...
%                 [main_folder '170913/GFP steam exp/frap_008.mat'], ...
%                 [main_folder '170913/GFP steam exp/frap_009.mat'], ...
%                 [main_folder '170913/GFP steam exp/frap_010.mat'], ...
%                 [main_folder '170913/steam exp i buffert/frap.mat'], ...
%                 [main_folder '170913/steam exp i buffert/frap_001.mat'], ...
%                 [main_folder '170913/steam exp i buffert/frap_002.mat'], ...
%                 [main_folder '170913/steam exp i buffert/frap_003.mat'], ...
%                 [main_folder '170913/steam exp i buffert/frap_004.mat'] }';

number_of_experiments = numel(file_paths);
idx_experiment = randsample(1:number_of_experiments, 1);
disp(['Analyzing ' file_paths{idx_experiment} '...'])

load(file_paths{idx_experiment});

data = experiment.postbleach.image_data;%(:, :, 1:10);%(:, :, 1:number_of_images);
number_of_images = size(data, 3);
data = double(data);
data = data / (2^experiment.postbleach.bit_depth - 1);

data_prebleach = experiment.prebleach.image_data;
data_prebleach = double(data_prebleach);
data_prebleach = data_prebleach / (2^experiment.prebleach.bit_depth - 1);
data_prebleach_avg = mean(data_prebleach, 3);
data = data - repmat(data_prebleach_avg, [1, 1, number_of_images]) + mean(data_prebleach_avg(:));

number_of_pixels = size(experiment.postbleach.image_data, 1);
x_bleach =  - experiment.bleach.bleach_position_x / experiment.postbleach.pixel_size_x + number_of_pixels / 2;
y_bleach = experiment.bleach.bleach_position_y / experiment.postbleach.pixel_size_y + number_of_pixels / 2;

if isequal(experiment.bleach.bleach_type, 'circle')
    r_bleach = experiment.bleach.bleach_size_x / experiment.postbleach.pixel_size_x;
    param_bleach = [x_bleach, y_bleach, r_bleach];
elseif isequal(experiment.bleach.bleach_type, 'rectangle')
    lx_bleach = experiment.bleach.bleach_size_x / experiment.postbleach.pixel_size_x;
    ly_bleach = experiment.bleach.bleach_size_y / experiment.postbleach.pixel_size_y;
    param_bleach = [x_bleach, y_bleach, lx_bleach, ly_bleach];
end

pixel_size = experiment.postbleach.pixel_size_x;
delta_t = experiment.postbleach.time_frame;

%% Estimate parameters.
number_of_pad_pixels = 128;

lb_D_SI = 1e-13;
ub_D_SI = 2e-9;
lb_D = lb_D_SI / pixel_size^2;
ub_D = ub_D_SI / pixel_size^2;


lb_mf = 0.6;
ub_mf = 1.0;

lb_Ib = 0.0;
ub_Ib = 1.0;

lb_Iu = 0.0;
ub_Iu = 1.2;

lb = [lb_D, lb_mf, lb_Ib, lb_Iu];
ub = [ub_D, ub_mf, ub_Ib, ub_Iu];

param_guess = [];
number_of_fits = 1;

[param_hat, ss] = estimate_d_rc( ...
    data, ...
    param_bleach, ...
    delta_t, ...
    number_of_pixels, ...
    number_of_images, ...
    number_of_pad_pixels, ...
    lb, ...
    ub, ...
    param_guess, ...
    number_of_fits);

file_path_output = [file_paths{idx_experiment}(1:end-4) '_est_d_rc_' num2str(random_seed) '.mat'];
save(file_path_output, 'param_hat', 'ss');
