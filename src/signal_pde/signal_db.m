function signal = signal_db(D, ...
                            k_on, ...
                            k_off, ...
                            mobile_fraction, ...
                            Ib, ...
                            Iu, ...
                            x_bleach, ...
                            y_bleach, ...
                            r_bleach, ...
                            delta_t, ...
                            number_of_pixels, ...
                            number_of_images, ...
                            number_of_pad_pixels)

% Marginal probabilities of the states.
p_free = k_off / ( k_on + k_off );
p_bound = k_on / ( k_on + k_off );

% Initial condition. Create a high resolution initial condition which is 
% then downsampled to avoid too sharp edges. Distribute bound and free 
% according to their marginal probabilities.

upsampling_factor = 3;

[X, Y] = meshgrid(1:upsampling_factor*(number_of_pixels + 2 * number_of_pad_pixels), 1:upsampling_factor*(number_of_pixels + 2 * number_of_pad_pixels));
X = X - 0.5;
Y = Y - 0.5;
x_bleach = number_of_pad_pixels + x_bleach;
y_bleach = number_of_pad_pixels + y_bleach;

C0 = zeros(size(X));
C0( (X - upsampling_factor * x_bleach).^2 + (Y - upsampling_factor * y_bleach).^2 <= (upsampling_factor * r_bleach)^2 ) = Ib;
C0( (X - upsampling_factor * x_bleach).^2 + (Y - upsampling_factor * y_bleach).^2 > (upsampling_factor * r_bleach)^2 ) = Iu;

C0 = imresize(C0, [number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels]);

B0 = p_bound * C0;
U0 = p_free * C0;

% FFT of initial conditions.
F_U0 = fft2(U0);
F_B0 = fft2(B0);

% Storage of FFT solution and final solution
F_U = zeros(number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels, number_of_images);
F_B = zeros(number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels, number_of_images);

signal = zeros(number_of_pixels + 2 * number_of_pad_pixels, number_of_pixels + 2 * number_of_pad_pixels, number_of_images);

% Fourier space grid and squared magnitude, correctly shifted.
[XSI1, XSI2] = meshgrid(-(number_of_pixels + 2 * number_of_pad_pixels)/2:(number_of_pixels + 2 * number_of_pad_pixels)/2-1, ...
                        -(number_of_pixels + 2 * number_of_pad_pixels)/2:(number_of_pixels + 2 * number_of_pad_pixels)/2-1);
XSI1 = XSI1 * 2 * pi / (number_of_pixels + 2 * number_of_pad_pixels);
XSI2 = XSI2 * 2 * pi / (number_of_pixels + 2 * number_of_pad_pixels);
XSISQ = XSI1.^2 + XSI2.^2;
XSISQ = ifftshift(XSISQ);

% Precompute elements of the different matrices of the diagonalized form
% of the PDE system matrix, excluding time t which DD will be multiplied 
% with later.
PP11 = -(k_on - k_off + (D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ + k_on^2 + 2.*k_on.*k_off + k_off^2).^(1./2) + D.*XSISQ)./(2.*k_on);
PP12 = -(k_on - k_off - (D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ + k_on^2 + 2.*k_on.*k_off + k_off^2).^(1./2) + D.*XSISQ)./(2.*k_on);

DD11 = -((k_on + k_off + (D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ + k_on^2 + 2.*k_on.*k_off + k_off^2).^(1./2) + D.*XSISQ))./2;
DD22 = -((k_on + k_off - (D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ + k_on^2 + 2.*k_on.*k_off + k_off^2).^(1./2) + D.*XSISQ))./2;

PPinv11 = -k_on./(2.*k_on.*k_off + k_on^2 + k_off^2 + D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ).^(1./2);
PPinv12 = -(k_on - k_off - (D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ + k_on^2 + 2.*k_on.*k_off + k_off^2).^(1./2) + D.*XSISQ)./(2.*(2.*k_on.*k_off + k_on^2 + k_off^2 + D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ).^(1./2));
PPinv21 = -PPinv11;
PPinv22 = (k_on - k_off + (D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ + k_on^2 + 2.*k_on.*k_off + k_off^2).^(1./2) + D.*XSISQ)./(2.*(2.*k_on.*k_off + k_on^2 + k_off^2 + D^2.*XSISQ.^2 + 2.*D.*k_on.*XSISQ - 2.*D.*k_off.*XSISQ).^(1./2));

% Time evolution in Fourier space.
CONST11 = PP11 .* (PPinv11 .* F_U0 + PPinv12 .* F_B0);
CONST12 = PP12 .* (PPinv21 .* F_U0 + PPinv22 .* F_B0);
CONST21 = PPinv11 .* F_U0 + PPinv12 .* F_B0;
CONST22 = PPinv21 .* F_U0 + PPinv22 .* F_B0;

for t = 1:number_of_images
    T = t * delta_t;
    CONST1 = exp(DD11 * T);
    CONST2 = exp(DD22 * T);
    F_B(:, :, t) = CONST11 .* CONST1 + CONST12 .* CONST2;
    F_U(:, :, t) = CONST21 .* CONST1 + CONST22 .* CONST2;
end

% Inverse transform.
for t = 1:number_of_images
    signal(:, :, t) = abs(ifft2(F_U(:, :, t) + F_B(:, :, t)));
end
signal = signal(number_of_pad_pixels+1:end-number_of_pad_pixels, number_of_pad_pixels+1:end-number_of_pad_pixels, :);

% Take (im)mobile fraction into account and add the free and bound
% contribution to the fluorescence. Even though U0 and B0 are 2-dim
% matrices, they are actually added to each slice in dim 3 of the 3-D
% matrix by writing like this.
signal = mobile_fraction * signal + (1 - mobile_fraction) * C0(number_of_pad_pixels+1:end-number_of_pad_pixels, number_of_pad_pixels+1:end-number_of_pad_pixels);

end
