%% Initialization.
clear
clc
close all hidden

%% Measurement parameters.
delta_t = 0.25; % s
number_of_post_bleach_images = 5;
number_of_pixels = 256;
number_of_pad_pixels = 0%128;
r_bleach_region = 32; % pixels

intensity_inside_bleach_region = 0.6;
intensity_outside_bleach_region = 0.9;

%% Particle parameters.
D = 400; % pixels^2 / s
k_on = 0.5; % 1/s
k_off = 1.0; % 1/s

p_free = k_off / ( k_on + k_off );
p_bound = k_on / ( k_on + k_off );

%% Initial condition. 
% Create a high resolution initial condition which is then downsampled to 
% avoid too sharp edges.

upsampling_factor = 3;

[X, Y] = meshgrid(1:upsampling_factor*(number_of_pixels + 2 * number_of_pad_pixels), 1:upsampling_factor*(number_of_pixels + 2 * number_of_pad_pixels));
X = X - 0.5;
Y = Y - 0.5;
xc = number_of_pad_pixels + number_of_pixels / 2;
yc = number_of_pad_pixels + number_of_pixels / 2;

U0 = zeros(size(X));
U0( (X - upsampling_factor * xc).^2 + (Y - upsampling_factor * yc).^2 <= (upsampling_factor * r_bleach_region)^2 ) = intensity_inside_bleach_region;
U0( (X - upsampling_factor * xc).^2 + (Y - upsampling_factor * yc).^2 > (upsampling_factor * r_bleach_region)^2 ) = intensity_outside_bleach_region;

% Distribute bound and free according to their marginal distribution,
% defined by p_free and p_bound.
B0 = p_bound * U0;
U0 = p_free * U0;

B0 = imresize(B0, [number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels]);
U0 = imresize(U0, [number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels]);

clear X Y

%% FFT of initial conditions.

F_U0 = fftshift(fft2(U0));
F_B0 = fftshift(fft2(B0));

%% FFT space time evolution of PDE system.

F_image_data_post_bleach_u = zeros(number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels, number_of_post_bleach_images);
F_image_data_post_bleach_b = zeros(number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels, number_of_post_bleach_images);
image_data_post_bleach_u = zeros(number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels, number_of_post_bleach_images);
image_data_post_bleach_b = zeros(number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels, number_of_post_bleach_images);

[XSI1, XSI2] = meshgrid(-(number_of_pixels + 2 * number_of_pad_pixels)/2:(number_of_pixels + 2 * number_of_pad_pixels)/2-1, ...
                        -(number_of_pixels + 2 * number_of_pad_pixels)/2:(number_of_pixels + 2 * number_of_pad_pixels)/2-1);
XSISQ = XSI1.^2 + XSI2.^2;

T = delta_t * (1:number_of_post_bleach_images);

for t = 1:number_of_post_bleach_images
    for i = 1:(number_of_pixels + 2 * number_of_pad_pixels)
        disp([t, i])
        for j = 1:(number_of_pixels + 2 * number_of_pad_pixels)
            A = [- D * XSISQ(i, j) - k_on, k_off ; k_on, - k_off];
            c_vector_hat = expm( A * T(t) ) * [F_U0(i, j) ; F_B0(i, j)];
            
            F_image_data_post_bleach_u(i, j, t) = c_vector_hat(1);
            F_image_data_post_bleach_b(i, j, t) = c_vector_hat(2);
        end
    end
end

for t = 1:number_of_post_bleach_images
    image_data_post_bleach_u(:, :, t) = abs(ifft2(ifftshift(F_image_data_post_bleach_u(:, :, t))));
    image_data_post_bleach_b(:, :, t) = abs(ifft2(ifftshift(F_image_data_post_bleach_b(:, :, t))));
end

image_data_post_bleach_u = image_data_post_bleach_u(number_of_pad_pixels+1:end-number_of_pad_pixels, :);
image_data_post_bleach_b = image_data_post_bleach_b(number_of_pad_pixels+1:end-number_of_pad_pixels, :);

FRAP = image_data_post_bleach_u + image_data_post_bleach_b;

imagesc(reshape(FRAP, [number_of_pixels, number_of_pixels*number_of_post_bleach_images]))
axis 'equal'