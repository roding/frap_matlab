%% Initialization.
clear
clc
close all hidden

%% Load data.
load('simulated_data_diffusion.mat');
number_of_pixels = size(image_data_post_bleach, 1);

number_of_post_bleach_images = 10;
image_data_post_bleach = image_data_post_bleach(:, :, 1:number_of_post_bleach_images);

number_of_iterations = 1000;

number_of_time_points_fine_per_coarse = [];%500;

%% Add noise.
sigma_noise = 0.01;
image_data_post_bleach = image_data_post_bleach + sigma_noise * randn(size(image_data_post_bleach));

%% Parameter estimation pre-work.

% Set parameter bounds for first estimation.
lb_1 = [0, 0, 0]; % mobile_fraction, intensity_inside_bleach_region, intensity_outside_bleach_region
ub_1 = [1, 1, 1];

% Initial guess for first estimation.
param_hat_1 = [1.0, 0.5, 0.95];

% Set parameter bounds for second estimation.
lb_2_SI = 1e-12;
ub_2_SI = 1e-8;
lb_2 = lb_2_SI / pixel_size^2;
ub_2 = ub_2_SI / pixel_size^2;

% Initial guess for second estimation.
param_hat_2_SI = 1e-10;
param_hat_2 = param_hat_2_SI / pixel_size^2;

%% Least-squares optimization.

options_1 = optimoptions(@lsqnonlin);
options_1.Algorithm = 'trust-region-reflective';
options_1.Display = 'iter';
options_1.FunctionTolerance = 1e-6;
options_1.OptimalityTolerance = 1e-6;
options_1.StepTolerance = 1e-6;
options_1.CheckGradients = true;
options_1.SpecifyObjectiveGradient = true;

options_2 = optimoptions(@lsqnonlin);
options_2.Algorithm = 'trust-region-reflective';
options_2.Display = 'iter';
options_2.FunctionTolerance = 1e-6;
options_2.OptimalityTolerance = 1e-6;
options_2.StepTolerance = 1e-6;
options_2.MaxIterations = 1;
options_2.UseParallel = true;

for current_iteration = 1:number_of_iterations
    [image_data_post_bleach_model_unscaled, initial_condition_model_unscaled] = signal_diffusion(   param_hat_2, ...
                                                                                                    1.0, ...
                                                                                                    x_bleach, ...
                                                                                                    y_bleach, ...
                                                                                                    r_bleach, ...
                                                                                                    0.5, ...
                                                                                                    1.0, ...
                                                                                                    delta_t, ...
                                                                                                    number_of_time_points_fine_per_coarse, ...
                                                                                                    number_of_pixels, ...
                                                                                                    number_of_post_bleach_images, ...
                                                                                                    number_of_pad_pixels);
    fun_1 = @(param)residual_diffusion_partial( param(1), ...
                                                param(2), ...
                                                param(3), ...
                                                image_data_post_bleach, ...
                                                image_data_post_bleach_model_unscaled, ...
                                                initial_condition_model_unscaled);

    [param_hat_1, ss_1] = lsqnonlin(fun_1, param_hat_1, lb_1, ub_1, options_1);
    
    disp([param_hat_1 param_hat_2])
    
    fun_2 = @(param)residual_diffusion_full(param, ...
                                            param_hat_1(1), ...
                                            x_bleach, ...
                                            y_bleach, ...
                                            r_bleach, ...
                                            param_hat_1(2), ...
                                            param_hat_1(3), ...
                                            delta_t, ...
                                            number_of_time_points_fine_per_coarse, ...
                                            number_of_pad_pixels, ...
                                            image_data_post_bleach);

    [param_hat_2, ss_2] = lsqnonlin(fun_2, param_hat_2, lb_2, ub_2, options_2);
    
    disp([param_hat_1 param_hat_2])
end