function plot_dashboard(results)
%PLOT_DASHBOARD Dark-themed summary dashboard for Monte Carlo roadster
% performance results (see run_monte_carlo.m / analyze_results.m).

bg = [0.09 0.10 0.13];
fg = [0.92 0.93 0.96];
accent = [0.20 0.75 0.95];
accent2 = [0.95 0.45 0.25];

fig = figure('Color', bg, 'Name', 'Roadster Monte Carlo Dashboard', ...
    'Position', [100 100 1200 800]);
tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

valid = ~isnan(results.t_0_100_kmh_s);
nValid = sum(valid);
nTotal = height(results);

% --- Panel 1: histogram of 0-100 km/h times ---
ax1 = nexttile(tl, 1);
histogram(ax1, results.t_0_100_kmh_s(valid), 30, ...
    'FaceColor', accent, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
styleAxes(ax1, bg, fg);
xlabel(ax1, '0-100 km/h time (s)'); ylabel(ax1, 'Trials');
m = mean(results.t_0_100_kmh_s(valid));
s = std(results.t_0_100_kmh_s(valid));
title(ax1, sprintf('0-100 km/h: %.2f s \\pm %.2f s (n=%d/%d)', m, s, nValid, nTotal), ...
    'Color', fg);
xline(ax1, m, 'Color', accent2, 'LineWidth', 1.5);

% --- Panel 2: histogram of quarter-mile times ---
ax2 = nexttile(tl, 2);
qValid = ~isnan(results.t_quarterMile_s);
histogram(ax2, results.t_quarterMile_s(qValid), 30, ...
    'FaceColor', accent2, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
styleAxes(ax2, bg, fg);
xlabel(ax2, '1/4 mile time (s)'); ylabel(ax2, 'Trials');
mq = mean(results.t_quarterMile_s(qValid));
title(ax2, sprintf('Quarter mile: %.2f s (avg trap %.0f km/h)', ...
    mq, mean(results.trapSpeed_kmh(qValid))), 'Color', fg);

% --- Panel 3: sensitivity scatter (launch grip vs. 0-100 time, colored by mass) ---
ax3 = nexttile(tl, 3);
scatter(ax3, results.mu(valid), results.t_0_100_kmh_s(valid), 14, ...
    results.mass(valid), 'filled', 'MarkerFaceAlpha', 0.6);
styleAxes(ax3, bg, fg);
xlabel(ax3, 'Tire-road friction \mu'); ylabel(ax3, '0-100 km/h time (s)');
title(ax3, 'Sensitivity: launch grip vs. 0-100 time', 'Color', fg);
colormap(ax3, parula);
cb = colorbar(ax3); cb.Color = fg; cb.Label.String = 'mass (kg)'; cb.Label.Color = fg;

% --- Panel 4: percentile summary bar ---
ax4 = nexttile(tl, 4);
pcts = [10 50 90];
vals = prctile(results.t_0_100_kmh_s(valid), pcts);
bar(ax4, vals, 'FaceColor', accent);
ax4.XTickLabel = arrayfun(@(pp) sprintf('P%d', pp), pcts, 'UniformOutput', false);
styleAxes(ax4, bg, fg);
ylabel(ax4, '0-100 km/h time (s)');
title(ax4, 'Performance envelope (percentiles)', 'Color', fg);
for k = 1:numel(vals)
    text(ax4, k, vals(k), sprintf(' %.2fs', vals(k)), 'Color', fg, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

title(tl, 'Roadster Longitudinal Performance - Monte Carlo', ...
    'Color', fg, 'FontSize', 16, 'FontWeight', 'bold');

end

function styleAxes(ax, bg, fg)
ax.Color = bg;
ax.XColor = fg;
ax.YColor = fg;
ax.GridColor = fg;
ax.GridAlpha = 0.15;
grid(ax, 'on');
box(ax, 'off');
end
