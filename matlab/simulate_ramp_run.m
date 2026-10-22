function T = simulate_ramp_run(outCsv)
%SIMULATE_RAMP_RUN Multi-mode extension of the longitudinal model that follows
% the scenario of the reference "Roadstar" clip:
%   DRIVE        launch, cruise, brake to a stop at the ramp foot, short pause
%   RAMP CLIMB   creep up a ~165 deg loop ramp held on by a suction fan
%                (inverted ceiling run at the top)
%   RAMP DROP    leave the end of the ceiling, fan decays, free fall
%   AIRBORNE     wheel thrusters level the body and brake the descent
%   TOUCHDOWN    soft landing, brake to rest, then DRIVE (idle)
% Writes one row per video frame to outCsv for the 3D renderer.
%
% Drive-force law is the same as build_roadster_model.m:
%   F_wheel = min(T_peak, P_peak/(v/k_wheel + 0.5)) / k_wheel,  capped by mu*N.
% Ramp geometry, fan schedule, thrusters and driver profile are illustrative
% scenario choices (matched to the reference clip's timing), not measured data.

if nargin < 1, outCsv = 'ramp_run.csv'; end
p = default_vehicle_params();
m = p.mass.nominal; g = p.g; mu = p.mu.nominal;
k_aero = p.k_aero.nominal; Crr = p.Crr.nominal;
Tpk = p.T_peak.nominal; Ppk = p.P_peak.nominal; kw = p.k_wheel;

% --- ramp geometry: flat run-up, arc of radius R up to phiE, straight ceiling
L1 = 155; R = 9.5; phiE = deg2rad(165); Lc = 5;
sArc = R * phiE; sEnd = L1 + sArc + Lc;
xE = L1 + R * sin(phiE); zE = R * (1 - cos(phiE));

% --- driver profile (matched to the reference timing)
vCruise = 20.5; aCap = 0.65 * g; aBrake = 4.5; xStop = L1 + 0.6;
tPause = 1.5; vClimb = 3.6; aClimb = 0.7; Kp = 30000;
% --- suction fan: reaches 2.3*m*g by about 105 deg of ramp angle
FsK = 2.3; phiFan = deg2rad(105); tauFan = 0.6;
% --- flight: attitude PD, thruster descent profile
kpA = 6; kdA = 4.5; tFree = 0.9; aBz = 8; kvz = 6; vzTD = 0.8;

wheelbase = 2.7; hcg = 0.5; wheelR = 0.33;
dt = 0.0005; fps = 24; tMax = 45;

s = 0; v = 0; dirn = 1; parked = false; tStop = NaN; tGo = NaN;
Fs = 0; mode = 0; x = 0; z = 0; vx = 0; vz = 0; pitch = 0; omega = 0;
wheelAng = 0; tRel = NaN; tTD = NaN; landed = false; thrust = 0;
gf = 1; Nf = 0; Nr = 0; N = m * g; phi = 0;
rows = zeros(ceil(tMax * fps) + 2, 16); iOut = 0; nextOut = 0;

for k = 0:floor(tMax/dt)
    t = k * dt;
    switch mode
        case {0, 1, 3, 5}                       % on the ground / on the ramp
            if landed || s <= L1
                phi = 0; kap = 0; x = s; z = 0;
            elseif s <= L1 + sArc
                phi = (s - L1) / R; kap = 1 / R;
                x = L1 + R * sin(phi); z = R * (1 - cos(phi));
            else
                phi = phiE; kap = 0; d = s - (L1 + sArc);
                x = xE + d * cos(phiE); z = zE + d * sin(phiE);
            end
            pitch = phi;
            if mode == 0 && s > L1, mode = 1; end
            FsT = (mode == 1) * FsK * m * g * min(1, (phi / phiFan)^2);
            Fs = Fs + dt / tauFan * (FsT - Fs);
            N = m * g * cos(phi) + m * v^2 * kap + Fs;
            Favail = min(Tpk, Ppk / (v / kw + 0.5)) / kw;
            Fres = (k_aero * v^2 + Crr * max(N, 0)) * (v > 0.05);
            if mode == 0 || mode == 1
                if isnan(tGo)
                    vSet = min(vCruise, sqrt(2 * aBrake * max(xStop - s, 0)));
                    if s >= xStop - 0.02, vSet = 0; end
                    if mode == 1 && ~parked && v < 0.03 && s >= L1 + 0.3
                        parked = true; tStop = t;
                    end
                    if parked && t >= tStop + tPause
                        parked = false; tGo = t;
                    end
                else
                    vSet = min(vClimb, aClimb * (t - tGo));
                end
                if parked
                    v = 0; Ft = 0; Fres = 0; a = 0;
                else
                    Ft = min(max(Kp * (vSet - v), -1.4 * m * aBrake), ...
                        min([Favail, mu * max(N, 0), m * aCap + Fres + m * g * sin(phi)]));
                    a = (Ft - Fres - m * g * sin(phi)) / m;
                end
            elseif mode == 5
                Ft = -min(0.7 * mu * N, 0.7 * m * g) * (v > 0.05);
                a = (Ft - Fres) / m;
                if t > tTD + 1.6, mode = 3; end
            else
                Ft = 0; a = -v / dt * (v <= 0.05);  % idle: stay at rest
            end
            dN = m * a * hcg / wheelbase;
            Nf = max(N / 2 - dN, 0); Nr = max(N / 2 + dN, 0);
            gf = hypot((Ft - Fres) / m, (N - Fs) / m) / g;
            if mode == 1 && s >= sEnd              % end of the ceiling: drop
                mode = 4; vx = v * cos(phiE); vz = v * sin(phiE);
                omega = 0; tRel = t;
            else
                v = max(v + a * dt, 0); s = s + dirn * v * dt;
            end
        case {4, 2}                              % flight (free fall / thrusters)
            Fs = Fs + dt / 0.3 * (0 - Fs);
            omega = omega + (-kpA * pitch - kdA * omega) * dt;
            pitch = pitch + omega * dt;
            ax = 0; athr = 0;
            if mode == 4 && t - tRel >= tFree, mode = 2; end
            if mode == 2
                vzDes = -sqrt(2 * aBz * max(z - 0.05, 0) + vzTD^2);
                if vz < vzDes
                    athr = min(kvz * (vzDes - vz), 2.2 * g);
                end
                ax = min(max(-1.5 * vx, -3), 3);
            end
            vx = vx + ax * dt; vz = vz + (-g + athr) * dt;
            x = x + vx * dt; z = z + vz * dt;
            thrust = athr / g; v = hypot(vx, vz);
            Nf = 0; Nr = 0; N = 0;
            gf = hypot(ax, athr) / g;
            if mode == 4, gf = Fs / (m * g) * 0.3; end
            if z <= 0.02 && vz < 0 && mode == 2
                mode = 5; z = 0; pitch = 0; s = x; v = abs(vx);
                dirn = 1 - 2 * (vx < 0); landed = true; tTD = t; thrust = 0;
            end
    end
    wheelAng = wheelAng + dirn * v / wheelR * dt;

    if t >= nextOut - 1e-9
        iOut = iOut + 1; nextOut = nextOut + 1 / fps;
        rows(iOut, :) = [t, x, z, rad2deg(pitch), v * 3.6, gf, Fs / g, ...
            Nf / 2e3, Nf / 2e3, Nr / 2e3, Nr / 2e3, Fs / 1e3, m * g / 1e3, ...
            mode, wheelAng, (mode == 2) * thrust];
    end
    if mode == 3 && t > tTD + 1.6 + 2.5, break; end
end
rows = rows(1:iOut, :);
names = {'t','x','z','pitch_deg','speed_kmh','g_force','downforce_kg', ...
    'N_FL_kN','N_FR_kN','N_RL_kN','N_RR_kN','Fsuction_kN','mg_kN','mode', ...
    'wheel_rad','thrust_g'};
T = array2table(rows, 'VariableNames', names);
writetable(T, outCsv);
fprintf('frames=%d (%.1f s) | stop t=%.1f go t=%.1f | z_max=%.1f m | release t=%.1f | touchdown t=%.1f x=%.1f speed=%.1f km/h | max downforce=%.0f kg\n', ...
    height(T), height(T) / fps, tStop, tGo, max(T.z), tRel, tTD, x, T.speed_kmh(find(T.mode == 5, 1)), max(T.downforce_kg));
end
