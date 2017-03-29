clear
clc
close all hidden

files = dir('sim_study_results\*.mat');
number_of_files = numel(files);

param_true = [];
param_hat_px = [];
param_hat_rc = [];
sigma_noise = [];

for current_file = 1:number_of_files
    disp(current_file)
    file_path = ['sim_study_results\' files(current_file).name];
    file_data = load(file_path);
    
    param_true = [param_true ; file_data.param_true];
    param_hat_px = [param_hat_px ; file_data.param_hat_px];
    param_hat_rc = [param_hat_rc ; file_data.param_hat_rc];
    sigma_noise = [sigma_noise ; file_data.sigma_noise];
end

clear files number_of_files current_file file_path file_data

save('results.mat')
    