---
name: panel-selection-advisor
description: Suggest the right Grafana visualization for the metrics a user wants to track. Use when the user describes what they want to monitor (latency, error rate, CPU, queue depth, request counts, SLOs, logs, distributions, etc.) and needs to know which panel type to use and how to configure it. Pairs with the grafana-foundation-sdk skill to turn the recommendation into code.
---

# Panel selection advisor (Grafana visualization taste)

Picking the right visualization is most of what makes a dashboard readable. This skill maps
*what you are tracking* to *which panel to use* and how to configure it. Use it before writing
Foundation SDK code so each metric lands on the right viz, then implement with the
`grafana-foundation-sdk` skill.

## How to use

1. Ask (or infer) for each metric: **what is it** (rate, gauge, cumulative, distribution,
   categorical, log), **what question does it answer**, and **how is it read** (trend over time,
   current value, comparison, breakdown).
2. Match it to a row in the decision table below.
3. Apply the configuration notes (unit, thresholds, legend, reducer).
4. Group related panels into rows; lead with the most important signal (top-left).

## Decision table: metric shape → panel

| What you're tracking | Best panel | Why / config notes |
| --- | --- | --- |
| A value changing over time (latency, throughput, CPU%, memory) | **Time series** | The default for trends. Set `unit`, `min(0)` for non-negative metrics, legend with `{{label}}`. |
| One current number that matters now (uptime %, current RPS, error budget left) | **Stat** | Big readable value. `reduceOptions.calcs: ["lastNotNull"]`, add thresholds for color. |
| Current value against a known min/max (CPU% of capacity, disk used %, SLO attainment) | **Gauge** | Use when there's a meaningful ceiling. Set `min`/`max` + threshold steps. |
| Several entities ranked by one value (top-N endpoints, per-pod memory) | **Bar gauge** | Horizontal bars; `lastNotNull` reducer, `displayMode: gradient`. |
| Many series you must scan exact numbers for (per-instance status, inventory) | **Table** | Use transformations to join/organize; add value mappings and cell coloring. |
| Distribution / latency histogram over time (p50/p95/p99 buckets) | **Heatmap** | For `_bucket` histograms. Or plot p50/p95/p99 as 3 series on a **Time series**. |
| Composition / share of a whole (traffic by status class, cost by service) | **Pie chart** *(sparingly)* | Only for ≤5 slices that sum to a meaningful whole. Usually a stacked time series or bar gauge reads better. |
| Categorical counts compared side by side (errors by type, requests by region) | **Bar chart** | Discrete categories at a point in time. |
| Raw events / log lines | **Logs** | Pair with a Loki query; add a time series of log volume above it. |
| Up/down or state over time (service health, deploy markers) | **State timeline** | Discrete states across time; map values to colors. |
| Section header / explanation / runbook link | **Text (Markdown)** | Orient the reader; don't overuse. |

## Golden-signals defaults (services)

When the user just says "monitor my service," propose the four golden signals, each with its
natural viz:

- **Latency** — Time series of p50/p95/p99 (`histogram_quantile` over `_bucket`), unit seconds.
- **Traffic** — Time series of requests/sec (`sum(rate(...[5m]))`), unit req/s; plus a Stat for current RPS.
- **Errors** — Time series of error rate (`sum(rate(...{status=~"5.."}[5m])) / sum(rate(...[5m]))`), unit percent; Stat with red threshold.
- **Saturation** — Gauge or time series of the binding resource (CPU%, queue depth, connection pool), with a threshold near the limit.

## RED / USE shortcuts

- **RED** (request-driven services): **R**ate → time series + stat; **E**rrors → time series + stat with threshold; **D**uration → time series of percentiles.
- **USE** (resources): **U**tilization → gauge/time series with max; **S**aturation → time series with limit threshold; **E**rrors → stat/table count.

## Anti-patterns to steer away from

- A pie chart with 8+ slices, or for values that don't sum to a whole → use bar gauge or stacked time series.
- A gauge for an unbounded metric (no real max) → use a stat or time series.
- A table where a sparkline trend is what the user actually wants → time series.
- One time series panel with 30 unfiltered series → add a template variable filter or top-N.
- Dual Y-axes mixing unrelated units to "save space" → split into two panels.

Once panels are chosen, implement them with the `grafana-foundation-sdk` skill (use the
panel-type → package table in its `reference.md`).
