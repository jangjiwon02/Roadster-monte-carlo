# Roadster Monte Carlo Performance Simulation

[한국어로 보기 →](README.ko.md)

A MATLAB + Simulink project that simulates straight-line acceleration for a high-performance EV ("roadster"-style) and runs it hundreds of times under randomized operating conditions (tire grip, air density/drag, payload, motor derating, road grade) to produce a **performance distribution** — not a single 0-100 km/h number, but the spread you'd actually see run to run.

## Status: unverified first draft

⚠️ This was written in an environment with no licensed MATLAB/Simulink available, so none of it has actually been run yet. The physics and the Simulink wiring were worked through carefully, but **the first real run should be treated as a debugging session, not a guaranteed success**. The most likely failure point is `build_roadster_model.m` — a block path string or port count that doesn't match your MATLAB release. Simulink's error messages after a failed `add_block`/`add_line` call point directly at the line to fix.

If you're doing this together with Claude over a Remote Control session (so it can see your actual MATLAB output and iterate), that's the fastest way to get from "first draft" to "working."

## What this is (and isn't)

- **Is**: a simplified, single-track (point-mass, straight-line) longitudinal vehicle model — traction-limited launch, then a constant-torque/constant-power motor envelope, resisted by aerodynamic drag, rolling resistance, and road grade.
- **Isn't**: a reproduction of any specific real vehicle's actual drivetrain. No AWD torque vectoring, no suspension/weight transfer, no battery state-of-charge or thermal history over time, no lateral dynamics. It's a stand-in built to explore how performance *varies* under different conditions, not to match a manufacturer's claimed number exactly.

## How it works

```
matlab/
├── default_vehicle_params.m   # nominal values + Monte Carlo distributions (edit this to change the vehicle)
├── build_roadster_model.m     # builds & saves RoadsterLongitudinal.slx (run once, or whenever you change the diagram)
├── run_monte_carlo.m          # samples N trials, runs them all, saves results, opens the dashboard
├── analyze_results.m          # extracts 0-100 km/h time, 1/4 mile time + trap speed per trial
└── plot_dashboard.m           # dark-themed summary dashboard (histograms, sensitivity scatter, percentiles)
```

**Model**: `RoadsterLongitudinal.slx`, built from plain, long-stable Simulink blocks (Integrator, Gain, Sum, Divide, MinMax, Math Function, Constant, To Workspace) — no toolboxes beyond base MATLAB + Simulink are required. Every quantity that's randomized per Monte Carlo trial (mass, traction limit, drag, rolling/grade resistance, motor torque/power limits) is referenced by name in the block dialogs and set per-run via `Simulink.SimulationInput.setVariable` — the diagram itself never needs to be rebuilt between trials.

**Monte Carlo**: each trial independently samples (truncated-normal):
- vehicle mass (driver/cargo load)
- tire-road friction coefficient (road/tire condition)
- aerodynamic drag factor (air density + small Cd/area variation)
- rolling resistance coefficient
- road grade
- motor peak torque and peak power (battery/thermal derating)

...then simulates 0 → 12 s and extracts the time to reach 100 km/h and the quarter-mile (402.336 m) time + trap speed for that trial.

**Parallelism**: if you have Parallel Computing Toolbox, `run_monte_carlo.m` uses `parsim` automatically; otherwise it falls back to a plain sequential loop (slower, but needs nothing extra).

## Running it

```matlab
cd matlab
results = run_monte_carlo();        % 500 trials by default
% results = run_monte_carlo(2000);  % more trials, smoother distributions
```

This builds the model if it doesn't exist yet, runs the Monte Carlo batch, saves `monte_carlo_results.mat`, and opens the dashboard automatically. `results` is a table — one row per trial — with both the extracted metrics (`t_0_100_kmh_s`, `t_quarterMile_s`, `trapSpeed_kmh`, `vMax_kmh`) and the sampled condition for that trial (`mass`, `mu`, `k_aero`, `Crr`, `gradeDeg`, `T_peak`, `P_peak`), so you can slice/plot sensitivity however you like beyond the built-in dashboard.

To change the vehicle (lighter/heavier, grippier tires, more/less power, tighter/looser spread), edit `default_vehicle_params.m` — nothing else needs to change.

## Tuning the model once it runs

A few things worth checking/adjusting once you can actually run it:
- The nominal numbers in `default_vehicle_params.m` were picked to land in a plausible "very fast EV" range by hand-calculation, not validated against a real run — expect to retune `T_peak`/`P_peak`/`mu` once you see actual simulated times.
- `p.sim.stopTime` (12 s) should comfortably cover 0-100 km/h and the quarter mile for the nominal parameters; if a lot of trials show `NaN` in the results table, the vehicle in that trial was too slow to finish within the simulated window — either that's a real (slow) outlier worth keeping, or the stop time needs extending.
- `N = 500` trials is a reasonable default for smooth-looking histograms; drop it to ~50 while you're still debugging the model (much faster to iterate).

---

[한국어로 보기 →](README.ko.md)
