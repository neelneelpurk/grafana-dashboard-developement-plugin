---
name: dashboard-sync
description: Fetch an existing Grafana dashboard from its URL and push a dashboard back to Grafana using Playwright. Use when given a Grafana dashboard URL (e.g. http://host/d/<uid>/<slug>) to read its current JSON model through the browser session, or to provision/import a dashboard JSON into Grafana via Playwright (browser session or the Import UI) instead of an API token. Backs the update-dashboard, review-dashboard, and provision-dashboard commands.
---

# Fetch & push Grafana dashboards with Playwright

When you're handed a **Grafana URL** rather than a local file, use the browser's authenticated
session to read and write the dashboard — no separate API token required. This skill uses
**Playwright MCP** (bundled in `.mcp.json`; always call it "Playwright MCP" so the browser tools
are used). The Grafana base URL comes from the user's input or the `grafana_url` plugin option.

## Open and authenticate once

1. `browser_navigate` to the Grafana URL (the dashboard URL, or `${grafanaUrl}` directly).
2. If a login page appears, log in: use credentials the user already provided (or the example
   stack's `admin` / `admin`); otherwise **ask the user for the username and password** before
   proceeding. The bundled example stack enables anonymous access, so this is often skipped. The
   browser is isolated, so log in again per session rather than persisting credentials.
3. After this, the browser holds a session cookie that authorizes same-origin API calls — the
   basis for fetch/push below.

## Fetch an existing dashboard's JSON

Grafana dashboard URLs look like `…/d/<uid>/<slug>`. Read the model through the session with
`browser_evaluate`:

```js
async () => {
  const m = location.pathname.match(/\/d\/([^/]+)/);
  const uid = m ? m[1] : null;
  const res = await fetch(`/api/dashboards/uid/${uid}`, { headers: { Accept: 'application/json' } });
  if (!res.ok) return { error: res.status };
  const body = await res.json();
  return body;            // { dashboard: <model>, meta: {...} }
}
```

The returned `dashboard` field is the full dashboard model. Save it to a file (e.g.
`./previews/<uid>.json`) so the SDK/quality skills can work against it. Capture the
`meta.folderUid` too if you intend to push back into the same folder.

If `browser_evaluate` is unavailable, navigate to the dashboard's **JSON Model** view
(Dashboard settings → JSON Model) and read the textarea, or use the API URL directly in the
browser and read the page body.

## Push / provision a dashboard via Playwright

Two ways, in order of preference:

### A. Authenticated POST through the session (fast, for small/medium dashboards)

Use `browser_evaluate`, passing the model. Keep the payload modest in size; for very large
dashboards prefer the Import UI (B).

```js
async (model) => {
  const res = await fetch('/api/dashboards/db', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dashboard: model, overwrite: true }),
  });
  return { status: res.status, body: await res.json() };   // body.url is the new dashboard path
}
```

Pass the dashboard model as the function argument. Strip any stale top-level `id` from the model
first (an exported id that doesn't exist on the target is rejected); a fresh SDK-generated model
has none.

### B. Grafana Import UI (most reliable, mirrors a human)

1. `browser_navigate` to `${grafanaUrl}/dashboard/import`.
2. Provide the JSON one of two ways:
   - **Upload**: `browser_file_upload` the dashboard `.json` file onto the file input, **or**
   - **Paste**: `browser_type` the JSON into the "Import via dashboard JSON model" textarea.
3. Click **Load**.
4. On the options screen, set the **folder** and map the **data source** if prompted, then click
   **Import**.
5. `browser_snapshot` to confirm the dashboard opened and panels render.

## After pushing

Confirm success: `browser_navigate` to the returned dashboard URL (or the one shown after
Import), `browser_snapshot` to check panels load, and `browser_take_screenshot` to
`./previews/<uid>.png` for the quality check. Report the final dashboard URL.

## When to use the HTTP script instead

If you have an API token or basic-auth credentials and don't need a browser, the
`skills/grafana-foundation-sdk/scripts/provision-dashboard.sh` script pushes via the HTTP API and
is simpler for automation. Use Playwright (this skill) when you only have a browser session / URL,
when the user explicitly wants the push done through Playwright, or when you also want a rendered
screenshot in the same browser session.
