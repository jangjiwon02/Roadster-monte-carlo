function T = analyze_results(simOut, p)
%ANALYZE_RESULTS Extract 0-100 km/h time and quarter-mile time/trap speed
% from an array of Simulink.SimulationOutput returned by run_monte_carlo.
%
% T is a table with one row per trial. A trial that failed, or never
% reached the target speed/distance within the simulated time, gets NaN
% in the corresponding column rather than being dropped -- keep that in
% mind when computing summary statistics (use the 'omitnan' flag, or
% filter with ~isnan first).

if nargin < 2 || isempty(p)
    p = default_vehicle_params();
end

N = numel(simOut);
t_0_100 = nan(N, 1);
t_quarterMile = nan(N, 1);
trapSpeed_kmh = nan(N, 1);
vMax_kmh = nan(N, 1);

for i = 1:N
    try
        vout = simOut(i).get('v_out');
        sout = simOut(i).get('s_out');
        vt = vout.time;
        vv = vout.signals.values(:);
        st = sout.time;
        ss = sout.signals.values(:);
    catch
        continue;   % trial failed, or didn't log -- leave this row as NaN
    end

    vMax_kmh(i) = max(vv) * 3.6;
    t_0_100(i) = firstCrossing(vt, vv, p.sim.target_mps);

    tq = firstCrossing(st, ss, p.sim.quarterMile_m);
    t_quarterMile(i) = tq;
    if ~isnan(tq)
        trapSpeed_kmh(i) = interp1(vt, vv, tq, 'linear', 'extrap') * 3.6;
    end
end

T = table(t_0_100, t_quarterMile, trapSpeed_kmh, vMax_kmh, ...
    'VariableNames', {'t_0_100_kmh_s', 't_quarterMile_s', 'trapSpeed_kmh', 'vMax_kmh'});

end

function tCross = firstCrossing(t, y, target)
%FIRSTCROSSING Linear-interpolated time at which a monotonically
% increasing signal y first reaches target. NaN if it never does.
idx = find(y >= target, 1, 'first');
if isempty(idx)
    tCross = nan;
    return;
end
if idx == 1
    tCross = t(1);
    return;
end
t0 = t(idx-1); t1 = t(idx);
y0 = y(idx-1); y1 = y(idx);
if y1 == y0
    tCross = t1;
else
    frac = (target - y0) / (y1 - y0);
    tCross = t0 + frac * (t1 - t0);
end
end
