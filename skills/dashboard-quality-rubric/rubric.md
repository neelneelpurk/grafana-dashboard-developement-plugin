# Grafana Dashboard Quality & Taste Rubric (yes/no)

Every item below is answered **Yes** or **No** (or **N/A** if it genuinely can't be checked).
There is no partial credit. Each item is tagged **[critical]** or **[normal]**.

Answer each from **evidence**: a named panel, a JSON field, or what's visible in the Playwright
screenshot. The visual items (marked 👁) must be judged from the screenshot, not the JSON.

## Verdict rule

> **PASS** only if **every [critical] item is Yes** AND **at most 2 [normal] items are No**.
> Otherwise **FAIL**. Any single critical "No" is an automatic FAIL.

---

## Correctness (data & queries)

1. **[critical]** 👁 Every panel loads data — no "No data", datasource, or query errors.
2. **[critical]** Every panel has a datasource set and at least one target/query.
3. **[critical]** Each query actually answers its panel's question (correct metric, labels, and aggregation — no double-counting).
4. **[normal]** `rate()`/`increase()` use a sensible window (e.g. `[5m]`, not `[1s]`) for the scrape interval.
5. **[normal]** A stable `uid` is set so re-provisioning updates the dashboard instead of duplicating it.

## Visualization choice

6. **[critical]** 👁 Each metric uses an appropriate panel type (no gauge for unbounded values, no pie chart of a time series, no table where a trend is needed).
7. **[normal]** For a service, the golden signals (latency, traffic, errors, saturation) — or RED/USE — are represented where relevant.

## Layout & readability

8. **[critical]** 👁 The dashboard is readable at a glance — clear titles, no overlapping panels, the most important signal is prominent (top-left).
9. **[normal]** 👁 Panels are grouped into logical rows with headers and sit on a tidy grid (consistent sizing).
10. **[normal]** 👁 No panel is overcrowded (e.g. 30+ unfiltered series); series counts are restrained or filtered with a variable / top-N.

## Units, thresholds, legends

11. **[critical]** Every panel that shows a number has a unit set (no raw `1400000000`).
12. **[normal]** Thresholds are set where they add meaning, with sane colors (red = bad).
13. **[normal]** Legends are concise and templated (`{{instance}}`), not raw series dumps.

## Consistency

14. **[normal]** Datasources come from a `${datasource}` variable (or a single shared uid), not hard-coded per panel.
15. **[normal]** Naming, color semantics, and time range are consistent across the dashboard.

## Performance & hygiene

16. **[normal]** No obviously expensive/high-cardinality unbounded queries; default time range and refresh are reasonable.

## Visual taste & polish 👁

17. **[critical]** 👁 No misleading visuals — honest axes (e.g. zero baselines on bar charts), no chartjunk, units not lying about scale.
18. **[normal]** 👁 The dashboard looks deliberate and restrained — coherent palette, purposeful color, aligned whitespace, nothing extraneous.

---

When answering, every "No" must name the specific issue and panel so the "what to improve"
summary can turn it directly into a fix. Every taste "No" (items 17–18) must name a concrete
problem (clutter, inconsistent color, misleading axis) — never "feels off".
