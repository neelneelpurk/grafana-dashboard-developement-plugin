---
name: dashboard-preview
description: Provision a generated dashboard into a running Grafana and visually preview it with Playwright (MCP or CLI). Use after building a dashboard with the Foundation SDK to push it to Grafana, open it in a browser, capture screenshots, and confirm panels render with data. Required input for visual taste grading.
---

# Preview a Grafana dashboard with Playwright

Generating valid dashboard JSON is not enough — a dashboard is only good if it *looks* right
with real data. This skill provisions the dashboard into a running Grafana, drives a browser
with Playwright to render it, and captures screenshots that the `dashboard-quality-rubric`
skill grades.

## Prerequisites

- A running Grafana with the target data source configured. If the user has none, use the
  bundled example stack: `examples/observability-stack/` (`docker compose up -d`) brings up
  Grafana + Prometheus + a sample metrics generator. See its README.
- Grafana connection comes from the `grafana_url` / `grafana_token` plugin options (or
  `GRAFANA_URL` / `GRAFANA_TOKEN` env vars). The example stack defaults to
  `http://localhost:3000` with `admin` / `admin`.
- **Playwright MCP** is bundled with this plugin (`.mcp.json`). Prefer the MCP tools
  (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_click`, etc.).
  Always refer to it as "Playwright MCP" so the browser tools are used rather than shell
  Playwright. If MCP is unavailable, fall back to the Playwright CLI script in `scripts/`.

## Workflow

1. **Provision** the dashboard JSON:
   `skills/grafana-foundation-sdk/scripts/provision-dashboard.sh dashboard.json`
   The script prints the dashboard URL on success.

2. **Render with data.** Append render params to the URL so a screenshot has a populated,
   deterministic time range and the kiosk chrome is hidden:
   `<dashboard-url>?from=now-6h&to=now&refresh=&kiosk`

3. **Drive the browser (Playwright MCP):**
   - `browser_navigate` to the Grafana dashboard URL. If Grafana shows a login page, fill
     username/password (`browser_type`) and submit, then navigate again.
   - Wait for panels to load — `browser_snapshot` and confirm panel titles appear and there are
     no "No data" / "Datasource error" strings in the accessibility tree.
   - `browser_take_screenshot` (full page) and save to `./previews/<uid>-overview.png`.
   - For a focused view, screenshot individual panels by their bounding element where useful.

4. **Sanity checks** before declaring success — report any that fail:
   - Every panel renders a value or series (no empty/"No data" panels).
   - No panel shows a datasource or query error.
   - Axes/units look sane (no `1.0000000001e9` raw bytes where a unit should apply).
   - Layout: no overlapping panels, no single panel spanning the whole row by accident.

5. **Hand off** the screenshot paths plus the dashboard JSON to the
   `dashboard-quality-rubric` skill for scoring.

## Capturing without a browser session (server-side render)

Grafana can render a panel/dashboard to PNG server-side if the image-renderer plugin is
installed: `GET /render/d/<uid>/<slug>?width=1600&height=900&from=now-6h&to=now`. Use this when
no interactive browser is available; otherwise prefer Playwright MCP for full-page fidelity and
interaction (variable selection, time range changes).

## Notes

- Screenshots are evidence for grading; keep them in `./previews/` and reference them by path.
- If panels are empty, the problem is usually the data source uid in the dashboard JSON not
  matching the provisioned data source, or the time range having no data. Fix the dashboard and
  re-provision rather than papering over it in the screenshot.
