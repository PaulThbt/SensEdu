function dist_vector = read_distance_data(arduino, mic_num)
    dist_vector = zeros(mic_num, 1);
    for i = 1:mic_num
        serial_rx_data = read(arduino, 4, 'uint8'); % 32bit per one distance measurement
        dist_vector(i, 1) = double(typecast(uint8(serial_rx_data), 'uint32'))/1e6; % expected in micrometers
    end
end