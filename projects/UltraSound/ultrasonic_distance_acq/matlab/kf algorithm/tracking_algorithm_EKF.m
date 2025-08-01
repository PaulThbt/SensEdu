% EXTENDED KALMAN FILTER IMPLEMENTATION 
%clear all
clc
close all
%% Algorithm
%-----------------SETTINGS----------------------------%
REAL_MEASUREMENTS = true; % true if real measurement data used
SPEAKER = 1; % 1 - speaker1 (ch1), 2 - speaker2(ch 2)
scale_fac = 1; % for microphone position tweaking
MIC_NUM = 4;
mic_name = {"MIC 1", "MIC 2","MIC 3", "MIC 4"};
% m1 = [-18.710e-3, 18.700e-3, 0.0];
% m2 = [-18.710e-3, -18.700e-3, 0.0];
% m3 = [18.740e-3, 18.750e-3, 0.0];
% m4 = [18.740e-3, -18.750e-3, 0.0];
m1 = [-0.02, 0.02, 0.0];
m2 = [-0.02, -0.02, 0.0];
m3 = [0.02, 0.02, 0.0];
m4 = [0.02, -0.02, 0.0];
microphones_no_off = [m1; m2; m3; m4];
microphones = [m1; m2; m3; m4];

% for speaker 2 
if SPEAKER == 2
    for i = 1:MIC_NUM
        microphones(i,:) = microphones(i,:) + [0.035, 0.0, 0.0];
    end
end

%---------------PREPROCESSING REAL MEASUREMENTS-----------------------%

if (REAL_MEASUREMENTS == true)
%    load("good measurements for tracking\xxlboard_ball_ball_13-Jun-2025_10-50-40_very_good.mat");
    %[dist_matrix, time_axis] = preprocess_real_measurements(measurement_data);
    dist_outliers = dist_matrix;
    dist_matrix = outlier_rejection(dist_matrix);

    pos_init_estimate = [0.0; 0.0; 0.25];

else
    % NON RANDOM TRAJECTORY 
    % Precomputation of trajectory to track
    % pos_true = single_pendulum_traj(tspan);
    pos_true = generate_object_trajectory(tspan, "helix", 0.2);
    % Having the ideal intial estimate
    pos_init_estimate = pos_true(:, 1); % The starting point of trajectory

end

% 1 INITIALIZATION
dtau = 1e-2; % s
N = size(dist_matrix, 2) - 1;
%N = 79;
simTime = N * dtau; % s
tspan = 0:dtau:simTime;


x_hat = [pos_init_estimate; 0;0;0]; % [x; y; z; vx; vy; vz] initial states


% prediction error covariance matrix
% to predict we first start at an initial state and then use a math model
% to propagate that into the future. There is uncertainty in this process
% which is captured in the prediction error covariance matrix P
% 0.02 good - go back to it
sigma_p = 0.002; % standard deviation
P =  eye(6) * (sigma_p^2); 

% This is the part where I include the brownian motion (viener process). I
% will use the formula from haralds phd thesis where he explained why we
% are using exactly this covariance matrix. This matrix is derived as a
% solution using Ito's lemma which is deals with the problem of solving
% stohastic differential equations

% process noise covariance matrix (related to our model which is not PERFECT!)
I = eye(3); % identity matrix 3x3
% 0.3 good, go back to it
sigma_q = 0.001; 
Q = dtau * [sigma_q^2 * I, (sigma_q^2/2)*dtau*I; 
           (sigma_q^2/2)*dtau*I, (sigma_q^2/3)*dtau^2*I]; 

% measurement noise covariance matrix
% uncorrelated measurements
% expected uncertainty that you have with the sensor measurements
sigma_r = 0.0005^2; % standard deviation -> variance is sigma_r^2
R = diag(ones(1, size(microphones,1))*sigma_r);

% Defining a container to put the measurements in for each step
num_steps = length(tspan);
state_history = NaN(6, num_steps);
trajectory_history = NaN(3, num_steps);
err_vec = zeros(size(microphones,1), num_steps);
K_vec = zeros(3, num_steps);
y_vec = err_vec;
K_hist = zeros(6, num_steps);
P_hist = zeros(6, 6, num_steps);

    
for k = 1:num_steps
    % 2 PREDICTION
    % predict state estimates
    x_hat_prior = stateTransitionFunction(x_hat, dtau);

    if REAL_MEASUREMENTS == true
        % read real measurement values
        y = dist_matrix(:,k);
    else
        % simulate measurement values
        y = get_measurements_fun(pos_true(:, k), microphones, sigma_r); 
    end
    y_vec(:, k) = y;

    F = jacobianStateTransition(x_hat, dtau);
    H = jacobianMeasurement(x_hat, microphones);
    
    % predict the error covariance (related to the state estimates)
    P_prior = F * P * F' + Q;
    
    % 3 CORRECT
    % innovation residual
    err = (y - measurementFunction(x_hat, microphones));
    err_vec(:, k) = err; % store innovation residual

    % innovation covariance
    S = H * P_prior * H' + R;

    % kalman gain - [0,1] reflects the relative uncertainty in the
    % prediction vs the measurement
    K = P_prior * H' * S^(-1);
    K_vec(:, k) = K(1:3, 1); % store kalman gain values

    % corrected state estimate
    x_hat = x_hat_prior + K * err;
    %x_hat(3) = abs(x_hat(3));

    % corrected estimate covariance matrix
    P = (eye(size(P)) - K * H) * P_prior;

    % store the new prediction
    state_history(:, k) = x_hat_prior;
end

%% Plot the position
% Plot the results - position
close
plot_trajectory(state_history, microphones, REAL_MEASUREMENTS, 1);
save_plot("Figures\3d_trajectory");
% %% Plot the measurements
% close;
% plot_measurements(y_vec);
% save_plot("Figures\measurements");
% %% Plot gain matrix
% close 
% plot_gain_matrix(K_vec);
% save_plot("Figures\kalman_gain");
% 
% %% Plot error matrix
% close 
% plot_error_matrix(err_vec, MIC_NUM);
% save_plot("Figures\error");
% %% Plot difference between dist with and w/o outliers
% close
% plot_measurements(dist_outliers);
% save_plot("Figures\outliers");