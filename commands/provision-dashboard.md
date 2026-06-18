---
description: Push a dashboard JSON to Grafana — via Playwright (browser session / Import UI) or the HTTP API script.
argument-hint: <path to dashboard JSON> [grafana URL] [api | playwright]
---

Provision the dashboard to Grafana. Input: **$ARGUMENTS** (a dashboard JSON file, an optional
Grafana base URL, and an optional method: `api` or `playwright`).

Resolve the target Grafana from the argument or the `grafana_url` plugin option. Pick the method:

- **Playwright** (default when only a browser session / URL is available, or when the user asks
  to push "with Playwright"): use the `dashboard-sync` skill to push through the browser —
  either an authenticated `POST /api/dashboards/db` via `browser_evaluate`, or the Grafana
  **Import UI** (`/dashboard/import` → upload/paste the JSON → Load → Import). No API token
  required; the browser session authorizes the write.
- **API** (when a token or basic-auth is configured): run
  `skills/grafana-foundation-sdk/scripts/provision-dashboard.sh <json> [folderUid]`, which POSTs
  to `/api/dashboards/db`, strips any stale `id`, and sets `overwrite: true`.

Either way: preserve the dashboard's `uid` and use `overwrite: true` so re-provisioning updates
the existing dashboard. After pushing, navigate to the resulting dashboard URL with Playwright,
`browser_snapshot` to confirm panels load, `browser_take_screenshot` to `./previews/`, and
report the final dashboard URL. If panels are empty, fix the datasource uid / time range and
re-push rather than reporting success.
