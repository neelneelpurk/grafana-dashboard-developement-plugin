# Grafana Dashboard Quality & Taste Rubric

Eight weighted dimensions, scored 0–5 each, totaling 100 points. Score against **evidence**
(named panels, JSON fields, the rendered screenshot), not impressions. Use the 0/3/5 anchors to
calibrate; 1, 2, 4 are intermediate.

---

## 1. Data correctness — weight 20

Does every panel actually show the right data, loaded and correct?

- **0** — Panels show "No data", datasource errors, or queries that don't answer the stated question.
- **3** — All panels load data; a few queries are imprecise (wrong rate window, missing `by` grouping, double-counting).
- **5** — Every panel loads, queries are correct and idiomatic (proper `rate()` windows, correct aggregation, no unit/label mistakes), and values match reality.

> Any "No data" or datasource error caps the **overall** grade at "Needs work".

## 2. Visualization choice — weight 15

Is each metric on the right panel type? (See the `panel-selection-advisor` skill.)

- **0** — Pervasive mismatches: gauges for unbounded metrics, pie charts of time series, tables where trends are needed.
- **3** — Mostly sensible; 1–2 panels would read better as another type.
- **5** — Every panel uses the viz that best answers its question; golden-signals/RED/USE patterns applied where relevant.

## 3. Layout & structure — weight 15

Grid, grouping, and reading order.

- **0** — Overlapping/ragged panels, no rows, no order; the eye has nowhere to start.
- **3** — Tidy grid and some grouping, but the most important signal isn't prioritized or rows are arbitrary.
- **5** — Clean grid, logical rows with headers, most important signals top-left, consistent panel sizing, sensible density.

## 4. Readability at a glance — weight 15

Can the intended viewer understand it in ~5 seconds? **Judge from the screenshot.**

- **0** — Cluttered; tiny text, 30+ unfiltered series, unclear what's healthy vs. broken.
- **3** — Legible but requires study; some overcrowded panels or unclear good/bad direction.
- **5** — Instantly scannable; clear titles, restrained series counts, color encodes health, key numbers pop.

## 5. Units, thresholds, legends — weight 10

The details that make numbers meaningful.

- **0** — Raw unitless numbers (`1400000000`), no thresholds, cryptic or missing legends.
- **3** — Most panels have units; thresholds/legends are inconsistent or partially missing.
- **5** — Correct units everywhere, meaningful thresholds with sane colors, concise templated legends (`{{instance}}`).

## 6. Consistency — weight 10

Does it feel like one coherent dashboard?

- **0** — Mixed color meanings, clashing time ranges, ad-hoc naming, hard-coded datasources.
- **3** — Generally consistent with a few outliers.
- **5** — Uniform naming, color semantics (red=bad), shared time range, template variables (`${datasource}`, `${job}`) instead of hard-coding.

## 7. Performance & query hygiene — weight 5

Will it stay fast and not melt the data source?

- **0** — Unbounded high-cardinality queries, `[1s]` rate windows, huge time ranges by default, per-series fan-out.
- **3** — Reasonable, with a couple of heavy or unbounded queries.
- **5** — Bounded cardinality, appropriate rate windows, sensible default time range/refresh, top-N where needed.

## 8. Visual taste & polish — weight 10

The craft layer. **Judge from the screenshot.** Every deduction must name a concrete issue.

- **0** — Noisy, inconsistent palette, decorative chartjunk, misleading axes (non-zero baselines on bar charts).
- **3** — Clean and inoffensive but unremarkable; minor inconsistencies.
- **5** — Deliberate and restrained: coherent palette, purposeful color, aligned whitespace, honest axes, nothing extraneous. Looks like someone cared.

---

## Weighted total → grade bands

| Score | Band | Meaning |
| --- | --- | --- |
| 90–100 | **Excellent** | Ship it; exemplary. |
| 80–89 | **Ship-ready** | Good; minor polish optional. |
| 65–79 | **Needs work** | Usable but has clear gaps to fix before sharing. |
| 40–64 | **Rough** | Significant issues across multiple dimensions. |
| 0–39 | **Broken** | Wrong data or unusable; rebuild key parts. |

Default acceptance bar: **≥ 80 (Ship-ready)**. Iterate build → preview → grade → fix until met,
unless the user sets a different bar.
