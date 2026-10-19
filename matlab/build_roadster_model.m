function mdl = build_roadster_model(modelName)
%BUILD_ROADSTER_MODEL Programmatically construct and save the single-track
% longitudinal EV performance model used by run_monte_carlo.m.
%
% This is a point-mass, straight-line model (no lateral dynamics, no
% suspension, no individual wheels): traction-limited launch, then a
% constant-torque/constant-power motor envelope, resisted by aerodynamic
% drag, rolling resistance, and road grade. It is a simplified stand-in
% for exploring performance sensitivity, NOT a reproduction of any real
% vehicle's actual drivetrain (it does not model AWD torque vectoring,
% thermal limits over time, battery state of charge, etc.).
%
% Every quantity that varies between Monte Carlo trials (mass, traction
% limit, aero drag, rolling/grade resistance, motor torque and power
% limits) is referenced by NAME inside block dialogs (e.g. the Gain block
% for aero drag has Gain = 'k_aero') rather than baked in as a literal
% number, so run_monte_carlo.m can set a different value per trial via
% Simulink.SimulationInput.setVariable without rebuilding the diagram.
%
% Usage:
%   build_roadster_model();               % builds 'RoadsterLongitudinal'
%   build_roadster_model('MyModelName');  % custom model name
%
% NOTE: this script was written and reasoned through carefully, but has
% not been run inside real MATLAB/Simulink yet (no licensed MATLAB was
% available in the environment that authored it). Treat the first run as
% a debugging session, not a guaranteed one-shot success -- most likely
% failure points are a block path string that differs slightly on your
% MATLAB release, or a port-count mismatch. Simulink's diagnostic
% messages after a failed add_block/add_line are the fastest way to spot
% exactly which line needs fixing.

if nargin < 1 || isempty(modelName)
    modelName = 'RoadsterLongitudinal';
end

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
existingFile = which([modelName '.slx']);
if ~isempty(existingFile)
    delete(existingFile);
end

new_system(modelName);
open_system(modelName);

% --- states ---
add_block('simulink/Continuous/Integrator', [modelName '/v_Integrator'], ...
    'Position', gridPos(1), 'InitialCondition', '0');
add_block('simulink/Continuous/Integrator', [modelName '/s_Integrator'], ...
    'Position', gridPos(2), 'InitialCondition', '0');

% --- motor torque/power envelope: T_avail = min(T_peak, P_peak / omega) ---
add_block('simulink/Math Operations/Gain', [modelName '/omega_Gain'], ...
    'Position', gridPos(3), 'Gain', '1/k_wheel');
add_block('simulink/Sources/Constant', [modelName '/eps_Const'], ...
    'Position', gridPos(4), 'Value', '0.5');
add_block('simulink/Math Operations/Sum', [modelName '/omega_safe_Sum'], ...
    'Position', gridPos(5), 'Inputs', '++');
add_block('simulink/Sources/Constant', [modelName '/Ppeak_Const'], ...
    'Position', gridPos(6), 'Value', 'P_peak');
add_block('simulink/Math Operations/Divide', [modelName '/TfromPower_Divide'], ...
    'Position', gridPos(7));
add_block('simulink/Sources/Constant', [modelName '/Tpeak_Const'], ...
    'Position', gridPos(8), 'Value', 'T_peak');
add_block('simulink/Math Operations/MinMax', [modelName '/Tavail_MinMax'], ...
    'Position', gridPos(9), 'Function', 'min', 'Inputs', '2');
add_block('simulink/Math Operations/Gain', [modelName '/Fwheel_Gain'], ...
    'Position', gridPos(10), 'Gain', '1/k_wheel');

% --- launch traction limit: F_tractive = min(F_wheel_raw, mu*m*g) ---
add_block('simulink/Sources/Constant', [modelName '/Ftracmax_Const'], ...
    'Position', gridPos(11), 'Value', 'F_trac_max');
add_block('simulink/Math Operations/MinMax', [modelName '/Ftrac_MinMax'], ...
    'Position', gridPos(12), 'Function', 'min', 'Inputs', '2');

% --- resistive forces: aero drag + rolling resistance + grade ---
add_block('simulink/Math Operations/Math Function', [modelName '/vsq_Math'], ...
    'Position', gridPos(13), 'Function', 'square');
add_block('simulink/Math Operations/Gain', [modelName '/Faero_Gain'], ...
    'Position', gridPos(14), 'Gain', 'k_aero');
add_block('simulink/Sources/Constant', [modelName '/kroll_Const'], ...
    'Position', gridPos(15), 'Value', 'k_roll');
add_block('simulink/Sources/Constant', [modelName '/Fgrade_Const'], ...
    'Position', gridPos(16), 'Value', 'F_grade');
add_block('simulink/Math Operations/Sum', [modelName '/Fresist_Sum'], ...
    'Position', gridPos(17), 'Inputs', '+++');

% --- net force -> acceleration ---
add_block('simulink/Math Operations/Sum', [modelName '/Fnet_Sum'], ...
    'Position', gridPos(18), 'Inputs', '+-');
add_block('simulink/Sources/Constant', [modelName '/m_Const'], ...
    'Position', gridPos(19), 'Value', 'm');
add_block('simulink/Math Operations/Divide', [modelName '/accel_Divide'], ...
    'Position', gridPos(20));

% --- logging ---
add_block('simulink/Sinks/To Workspace', [modelName '/v_ToWorkspace'], ...
    'Position', gridPos(21), 'VariableName', 'v_out', 'SaveFormat', 'StructureWithTime');
add_block('simulink/Sinks/To Workspace', [modelName '/s_ToWorkspace'], ...
    'Position', gridPos(22), 'VariableName', 's_out', 'SaveFormat', 'StructureWithTime');

% --- wiring (block names are relative to modelName, per add_line's usual
%     calling convention) ---

% v feedback branches out to four places; s_Integrator closes the distance loop
add_line(modelName, 'v_Integrator/1', 'omega_Gain/1');
add_line(modelName, 'v_Integrator/1', 'vsq_Math/1');
add_line(modelName, 'v_Integrator/1', 'v_ToWorkspace/1');
add_line(modelName, 'v_Integrator/1', 's_Integrator/1');
add_line(modelName, 's_Integrator/1', 's_ToWorkspace/1');

% motor envelope
add_line(modelName, 'omega_Gain/1', 'omega_safe_Sum/1');
add_line(modelName, 'eps_Const/1', 'omega_safe_Sum/2');
add_line(modelName, 'Ppeak_Const/1', 'TfromPower_Divide/1');
add_line(modelName, 'omega_safe_Sum/1', 'TfromPower_Divide/2');
add_line(modelName, 'Tpeak_Const/1', 'Tavail_MinMax/1');
add_line(modelName, 'TfromPower_Divide/1', 'Tavail_MinMax/2');
add_line(modelName, 'Tavail_MinMax/1', 'Fwheel_Gain/1');

% traction limit
add_line(modelName, 'Fwheel_Gain/1', 'Ftrac_MinMax/1');
add_line(modelName, 'Ftracmax_Const/1', 'Ftrac_MinMax/2');

% resistive forces
add_line(modelName, 'vsq_Math/1', 'Faero_Gain/1');
add_line(modelName, 'Faero_Gain/1', 'Fresist_Sum/1');
add_line(modelName, 'kroll_Const/1', 'Fresist_Sum/2');
add_line(modelName, 'Fgrade_Const/1', 'Fresist_Sum/3');

% net force -> acceleration -> back into v_Integrator (closes the ODE loop)
add_line(modelName, 'Ftrac_MinMax/1', 'Fnet_Sum/1');
add_line(modelName, 'Fresist_Sum/1', 'Fnet_Sum/2');
add_line(modelName, 'Fnet_Sum/1', 'accel_Divide/1');
add_line(modelName, 'm_Const/1', 'accel_Divide/2');
add_line(modelName, 'accel_Divide/1', 'v_Integrator/1');

% --- solver / model configuration ---
set_param(modelName, 'Solver', 'ode45', 'StopTime', '12', ...
    'MaxStep', '0.01', 'SaveOutput', 'off');

save_system(modelName);
close_system(modelName, 1);

mdl = modelName;

end

function pos = gridPos(idx)
%GRIDPOS Simple left-to-right, top-to-bottom grid layout for block
% positions, purely cosmetic (does not affect simulation behavior).
colWidth = 140; rowHeight = 90; blockW = 100; blockH = 40; rowsPerCol = 8;
col = floor((idx - 1) / rowsPerCol);
row = mod(idx - 1, rowsPerCol);
left = 30 + col * colWidth;
top  = 30 + row * rowHeight;
pos = [left, top, left + blockW, top + blockH];
end
