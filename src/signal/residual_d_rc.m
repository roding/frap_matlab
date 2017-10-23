function F = residual_d_rc( ...
    D, ...
    mf, ...
    Ib, ...
    Iu, ...
    param_bleach, ...
    delta_t, ...
    number_of_pixels, ...
    number_of_images, ...
    number_of_pad_pixels, ...
    data)

model = signal_d( ...
    D, ...
    mf, ...
    Ib, ...
    Iu, ...
    param_bleach, ...
    delta_t, ...
    number_of_pixels, ...
    number_of_images, ...
    number_of_pad_pixels);
                
[X, Y] = meshgrid(1:number_of_pixels, 1:number_of_pixels);
X = X - 0.5;
Y = Y - 0.5;

x_bleach = param_bleach(1);
y_bleach = param_bleach(2);
if numel(param_bleach) == 3 % Circular.
    r_bleach = param_bleach(3);
    ind = find( (X - x_bleach).^2 + (Y - y_bleach).^2 <= r_bleach^2 );
else % Rectangular.
    lx_bleach = param_bleach(3);
    ly_bleach = param_bleach(4);
    ind = find( X >= x_bleach - 0.5 * lx_bleach & X <= x_bleach + 0.5 * lx_bleach & Y >= y_bleach - 0.5 * ly_bleach & Y <= y_bleach + 0.5 * ly_bleach );
end
ind = ind(:);

rc_data = zeros(1, number_of_images);
for current_image = 1:number_of_images
    slice = data(:, :, current_image);
    rc_data(current_image) = mean(slice(ind));
end

rc_model = zeros(1, number_of_images);
for current_image = 1:number_of_images
    slice = model(:, :, current_image);
    rc_model(current_image) = mean(slice(ind));
end

F = rc_model(:) - rc_data(:);

end
