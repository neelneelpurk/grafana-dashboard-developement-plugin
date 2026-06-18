---
name: dashboard-quality-rubric
description: Run a yes/no quality-and-taste check on a Grafana dashboard and produce a pass/fail verdict plus a "what to improve" summary. This skill is self-contained: it uses Playwright MCP to open the dashboard and take a screenshot, inspects the dashboard JSON and the Foundation SDK source, answers every rubric item yes or no, then summarizes the fixes. Use after building a dashboard, or whenever the user asks to review, grade, taste-test, or check a Grafana dashboard.
---

# Dashboard quality & taste check (yes/no rubric)

A dashboard can be schema-valid and still be bad: wrong viz, no units, unreadable at a glance,
panels that don't load. This skill checks a dashboard against a **yes/no rubric** — every item
is a plain pass or fail, no fuzzy 0–5 scoring — and returns a clear **PASS / FAIL** verdict with
a **"what to improve"** summary listing each failed item and its fix.

This skill runs the whole evaluation itself. It does not just read JSON — it drives Playwright to
render the dashboard and it inspects the code, because taste and readability can only be judged
from the rendered result, and correctness from the source.

## Inputs

- The dashboard JSON (Foundation SDK output or exported from Grafana), and/or the dashboard
  `uid`/URL on a running Grafana. If given only a **Grafana URL**, use the `dashboard-sync` skill
  to fetch the current JSON model through Playwright first.
- The Foundation SDK source that produced it (for the code check), when available.

## Run the check (do all of this)

### 1. Render and screenshot with Playwright MCP (required — never skip)

**Every review takes screenshots.** A review without a screenshot is incomplete — do not grade
the visual items from JSON. Taking the screenshots is the first thing you do.

- Make sure the dashboard is provisioned into Grafana. If it isn't, provision it first with
  `skills/grafana-foundation-sdk/scripts/provision-dashboard.sh dashboard.json` (uses the
  `grafana_url` / `grafana_token` plugin options). If no Grafana is running, start the bundled
  `examples/observability-stack/` (`docker compose up -d`).
- Use **Playwright MCP** (bundled in this plugin's `.mcp.json`) — refer to it as "Playwright MCP"
  so the browser tools are used, not shell Playwright:
  - `browser_navigate` to `<dashboard-url>?from=now-6h&to=now&refresh=&kiosk`. If a login page
    appears, `browser_type` the credentials and submit, then navigate again. Give panels a few
    seconds to run their queries (`browser_wait_for`) before capturing.
  - `browser_snapshot` to read the accessibility tree; confirm panel titles are present and scan
    for "No data" / "Datasource error" / "Query error".
  - **Full-page screenshot** → `browser_take_screenshot` saved to `./previews/<uid>.png`. This is
    the primary evidence for the visual rubric items.
  - **Per-panel / per-row screenshots** where it helps the verdict — capture any panel you flag
    (e.g. a cluttered chart, a wrong viz, a misleading axis) as `./previews/<uid>-<panel>.png` so
    each visual "No" is backed by a specific image. At minimum, additionally screenshot each row
    on a large dashboard so nothing is judged unseen.
  - List **every** saved screenshot path in the report, and surface the key images to the user
    (e.g. with SendUserFile) so the evidence is visible, not just referenced.
- If — and only if — rendering is genuinely impossible (no reachable Grafana at all), say so
  explicitly at the top of the report and mark the visual items N/A. This is a degraded review,
  not a normal one; never silently skip the screenshot.

### 2. Check the code and JSON

- Read the dashboard JSON and the SDK source. Verify, in code: every panel has a `datasource`
  and at least one target; units are set; a stable `uid` exists; template variables
  (`${datasource}`, `${job}`) are used instead of hard-coded datasources; `rate()` windows and
  aggregations are sane; no obviously high-cardinality unbounded queries.

### 3. Answer the rubric

- Open `rubric.md` (this skill directory). It is a flat list of **yes/no items**, each marked
  **[critical]** or **[normal]**.
- Answer every item **Yes** or **No** with one line of **specific evidence** — name the panel,
  the JSON field, or what's visible in the screenshot. Never answer without a reason. If an item
  truly cannot be checked (e.g. no screenshot was possible), mark it **N/A** and say why.

### 4. Verdict

Apply this rule exactly:

> **PASS** only if **every [critical] item is Yes** AND **at most 2 [normal] items are No**.
> Otherwise **FAIL**.

A single critical "No" (e.g. a panel shows "No data") is an automatic FAIL.

### 5. "What to improve" summary

List every **No** (and any N/A worth resolving), critical items first, each as an actionable
fix: name the panel and the exact change. If the verdict is PASS, still list any normal "No"s as
optional polish. End with a one-sentence overall takeaway.

## Output format

```
# Dashboard Quality Check — <title>
Verdict: PASS ✅  |  FAIL ❌
Critical: <x>/<n> Yes   ·   Normal: <x>/<m> Yes

## Screenshots
- Full page: ./previews/<uid>.png
- <panel/row>: ./previews/<uid>-<panel>.png
- ... (every image captured) ...

## Rubric
[critical] Data loads in every panel (no "No data"/errors) ........... Yes — all 8 panels populated
[critical] Each panel has a correct datasource + target ............... Yes — ...
[critical] Correct visualization for each metric ...................... No  — "Queue" uses a pie chart for an unbounded gauge metric
[normal]   Units set on every panel ................................... No  — "Latency" panel is unitless
... (one line per rubric item) ...

## What to improve
1. (critical) "Queue" panel → switch pie chart to a gauge with min/max; pies don't fit unbounded values.
2. (normal)   "Latency" panel → set unit to seconds (`unit(units.Seconds)`).
...

Takeaway: <one sentence>.
```

After reporting, offer to apply the top fixes via the `grafana-foundation-sdk` skill and re-run
this check. Treat build → preview → check → fix as one loop; iterate until the verdict is PASS.
