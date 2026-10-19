function results = run_monte_carlo(N, modelName)
%RUN_MONTE_CARLO Sample N operating-condition trials from
% default_vehicle_params() and simulate the roadster longitudinal model
% for each, returning a table of performance metrics plus the sampled
% condition for every trial (so you can study sensitivity afterwards).
%
%   results = run_monte_carlo();        % N = 500, default model name
%   results = run_monte_carlo(2000);    % more trials
%
% Builds the model automatically (via build_roadster_model) if it isn't
% already saved as an .slx in the current folder. Also saves
% monte_carlo_results.mat and opens the summary dashboard
% (plot_dashboard.m) when done.
%
% Call rng(someSeed) yourself before this if you want a repeatable draw;
% otherwise each call uses a fresh random sequence.

if nargin < 1 || isempty(N)
    N = 500;
end
if nargin < 2 || isempty(modelName)
    modelName = 'RoadsterLongitudinal';
end

if isempty(which([modelName '.slx']))
    fprintf('Model %s.slx not found -- building it now.\n', modelName);
    build_roadster_model(modelName);
end

p = default_vehicle_params();

mass     = sampleNormal(p.mass.nominal, p.mass.sigma, N, [1, inf]);
mu       = sampleNormal(p.mu.nominal, p.mu.sigma, N, p.mu.bounds);
k_aero   = sampleNormal(p.k_aero.nominal, p.k_aero.sigma, N, [0, inf]);
Crr      = sampleNormal(p.Crr.nominal, p.Crr.sigma, N, [0, inf]);
gradeDeg = sampleNormal(p.gradeDeg.nominal, p.gradeDeg.sigma, N, [-90, 90]);
T_peak   = sampleNormal(p.T_peak.nominal, p.T_peak.sigma, N, [0, inf]);
P_peak   = sampleNormal(p.P_peak.nominal, p.P_peak.sigma, N, [0, inf]);

gradeRad   = deg2rad(gradeDeg);
F_trac_max = mu .* mass * p.g;
k_roll     = Crr .* mass * p.g .* cos(gradeRad);
F_grade    = mass * p.g .* sin(gradeRad);

for i = N:-1:1   % descending so the first assignment preallocates the array
    in(i) = Simulink.SimulationInput(modelName);
    in(i) = in(i).setVariable('m', mass(i));
    in(i) = in(i).setVariable('F_trac_max', F_trac_max(i));
    in(i) = in(i).setVariable('k_aero', k_aero(i));
    in(i) = in(i).setVariable('k_roll', k_roll(i));
    in(i) = in(i).setVariable('F_grade', F_grade(i));
    in(i) = in(i).setVariable('T_peak', T_peak(i));
    in(i) = in(i).setVariable('P_peak', P_peak(i));
    in(i) = in(i).setVariable('k_wheel', p.k_wheel);
end

useParallel = license('test', 'Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));
if useParallel
    fprintf('Running %d trials with parsim (Parallel Computing Toolbox detected)...\n', N);
    simOut = parsim(in);
else
    fprintf('Running %d trials sequentially (no Parallel Computing Toolbox found)...\n', N);
    simOut(N) = Simulink.SimulationOutput();
    reportEvery = max(1, floor(N / 20));
    for i = 1:N
        try
            simOut(i) = sim(in(i));
        catch ME
            fprintf('Trial %d failed: %s\n', i, ME.message);
        end
        if mod(i, reportEvery) == 0
            fprintf('  %d / %d\n', i, N);
        end
    end
end

results = analyze_results(simOut, p);
results.mass     = mass(:);
results.mu       = mu(:);
results.k_aero   = k_aero(:);
results.Crr      = Crr(:);
results.gradeDeg = gradeDeg(:);
results.T_peak   = T_peak(:);
results.P_peak   = P_peak(:);

save('monte_carlo_results.mat', 'results');
fprintf('Saved results to monte_carlo_results.mat\n');

plot_dashboard(results);

end

function x = sampleNormal(mu0, sigma, N, bounds)
%SAMPLENORMAL Draw N ~ Normal(mu0, sigma), re-drawing any sample outside
% [bounds(1), bounds(2)] (simple truncated-normal rejection sampling --
% adequate for the loose bounds used in this project).
x = mu0 + sigma * randn(N, 1);
bad = x < bounds(1) | x > bounds(2);
tries = 0;
while any(bad) && tries < 50
    x(bad) = mu0 + sigma * randn(sum(bad), 1);
    bad = x < bounds(1) | x > bounds(2);
    tries = tries + 1;
end
x = min(max(x, bounds(1)), bounds(2));   % hard clamp as a final safeguard
end
