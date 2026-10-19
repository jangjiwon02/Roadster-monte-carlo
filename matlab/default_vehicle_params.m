function p = default_vehicle_params()
%DEFAULT_VEHICLE_PARAMS Nominal values and Monte Carlo distributions for the
% roadster longitudinal performance model. Edit this file to change the
% vehicle or the spread of operating conditions being sampled.
%
% Every "nominal" field is the deterministic value a single baseline run
% would use. Every paired "sigma" controls how that quantity is randomized
% across trials in run_monte_carlo.m (independent, optionally-truncated
% normal distributions -- simple and adequate for a first version).
%
% Units are SI throughout (kg, m, s, N, W, rad) unless noted otherwise.

p = struct();

% --- Physical constants ---
p.g = 9.80665;

% --- Fixed mechanical constants (vehicle design parameters, not randomized
%     as operating conditions) ---
p.k_wheel = 0.33;   % lumped effective rolling radius / gear ratio, m

% --- Vehicle mass: driver + cargo load variation ---
p.mass.nominal = 1750;   % kg
p.mass.sigma   = 50;     % kg

% --- Tire/road friction coefficient (launch traction limit) ---
p.mu.nominal = 0.95;
p.mu.sigma   = 0.08;
p.mu.bounds  = [0.5, 1.1];   % truncate to a physically sane range

% --- Aerodynamics: k_aero = 0.5 * rho * Cd * frontalArea, N / (m/s)^2 ---
% Nominal corresponds roughly to Cd=0.28, frontal area=2.0 m^2, rho=1.225 kg/m^3.
p.k_aero.nominal = 0.343;
p.k_aero.sigma   = 0.02;

% --- Rolling resistance coefficient ---
p.Crr.nominal = 0.012;
p.Crr.sigma   = 0.001;

% --- Road grade, degrees (+ = uphill) ---
p.gradeDeg.nominal = 0;
p.gradeDeg.sigma   = 0.5;

% --- Motor envelope, both already wheel-equivalent (i.e. post-gearing
%     torque/power delivered at the wheel contact patch, NOT at the motor
%     shaft -- this keeps the Simulink model from needing gear_ratio /
%     wheel_radius as separate parameters) ---
p.T_peak.nominal = 8250;     % N*m, wheel-equivalent peak torque (traction-limited launch regime)
p.T_peak.sigma   = 300;      % motor current-limit / battery variability

p.P_peak.nominal = 400000;   % W, wheel-equivalent peak power (high-speed, power-limited regime)
p.P_peak.sigma   = 15000;    % thermal / voltage-sag derating variability

% --- Simulation run configuration ---
p.sim.stopTime       = 12;         % s, long enough to clear 0-100 km/h with margin
p.sim.maxStep        = 0.01;       % s
p.sim.quarterMile_m  = 402.336;    % 1/4 mile, meters
p.sim.target_kmh     = 100;
p.sim.target_mps     = p.sim.target_kmh / 3.6;

end
