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

The screenshot **always** comes from a real browser session that opens the Grafana dashboard.
That is the point of this skill — open the dashboard in a browser and capture what a user would
actually see. Do not infer the look from JSON or skip the browser.

1. **Provision** the dashboard JSON:
   `skills/grafana-foundation-sdk/scripts/provision-dashboard.sh dashboard.json`
   The script prints the dashboard URL on success. (If reviewing an existing dashboard from a
   Grafana URL, skip this — you already have the URL.)

2. **Open a browser session (Playwright MCP).** This is the required path — refer to it as
   "Playwright MCP" so the browser tools are used, not shell Playwright:
   - `browser_navigate` to the dashboard URL with render params so the capture has a populated,
     deterministic time range and the Grafana chrome is hidden:
     `<dashboard-url>?from=now-6h&to=now&refresh=&kiosk`
   - If Grafana shows a login page, how you authenticate depends on the auth type:
     - **OIDC / SSO / SAML (an external identity provider, possibly with MFA):** the automated
       browser cannot drive this flow, and you must not try. Instead reuse a session the user
       logged in with themselves — a captured storage-state file or their live Chrome over CDP
       (see "Reusing a Chrome login" below). If neither is configured, ask the user to run
       `capture-session.sh` (they complete the SSO flow once) or to start Chrome with a debug
       port, rather than asking for a password.
     - **Basic Grafana username/password form (e.g. the local example stack):** use credentials
       the user provided (or the example's `admin` / `admin`), filling them with `browser_type` /
       `browser_fill_form`. If unknown, ask the user.
     The browser runs isolated, so a session lasts only for this review — that's fine; reuse a
     saved/live session next time rather than persisting credentials.
   - Let panels finish querying — `browser_wait_for` a few seconds, then `browser_snapshot` and
     confirm panel titles appear with no "No data" / "Datasource error" / "Query error" strings.

3. **Take the screenshots in that session:**
   - **Full page** → `browser_take_screenshot` saved to `./previews/<uid>.png`.
   - **Per-panel / per-row** for anything notable → `./previews/<uid>-<panel>.png`.
   - List every saved image and surface the key ones to the user (e.g. SendUserFile).

4. **Sanity checks** before declaring success — report any that fail:
   - Every panel renders a value or series (no empty/"No data" panels).
   - No panel shows a datasource or query error.
   - Axes/units look sane (no `1.0000000001e9` raw bytes where a unit should apply).
   - Layout: no overlapping panels, no single panel spanning the whole row by accident.

5. **Hand off** the screenshot paths plus the dashboard JSON to the
   `dashboard-quality-rubric` skill for scoring.

### If Playwright MCP isn't available

Run the bundled headless browser-session script, which does the same thing (opens the dashboard,
logs in if needed, waits, screenshots):

```bash
node skills/dashboard-preview/scripts/screenshot.mjs \
  "<dashboard-url>" ./previews/<uid>.png [user] [pass]
```

Only as a last resort, if no browser can run at all, Grafana can render server-side **when the
image-renderer plugin is installed**: `GET /render/d/<uid>/<slug>?width=1600&height=900&from=now-6h&to=now`.
This is a fallback, not the normal path — the browser session above is preferred for fidelity and
interaction (variable selection, time-range changes).

## Reusing a Chrome login (required for OIDC / SSO)

By default the browser is isolated and you log in each session. **For OIDC/SSO/SAML auth this is
the only workable path** — a human completes the full identity-provider flow (redirects, MFA)
once in a real browser, and Playwright reuses the resulting session. The automated browser never
drives the SSO flow itself. Pick one — the bundled Playwright MCP and `screenshot.mjs` both honor
these:

1. **Saved session file (recommended, portable; works with any SSO).** Log in once and save the
   session:
   ```bash
   skills/dashboard-preview/scripts/capture-session.sh http://localhost:3000 grafana-auth.json
   ```
   This opens a real browser; complete the **entire login — including the SSO/OIDC redirect and
   MFA** — then close the window to write `grafana-auth.json` (cookies + tokens for the session).
   Reuse it by setting the `grafana_storage_state` plugin option (or `GRAFANA_STORAGE_STATE`) to
   its absolute path — the Playwright MCP then starts already authenticated. For the CLI:
   `node screenshot.mjs <url> out.png --storage-state grafana-auth.json`. Re-capture when the
   session expires.

2. **Your live Chrome over CDP.** Start Chrome with a debug port and a dedicated profile, log in,
   then point Playwright at it:
   ```bash
   google-chrome --remote-debugging-port=9222 --user-data-dir="$HOME/.chrome-grafana"
   ```
   Set the `grafana_cdp_endpoint` plugin option (or `GRAFANA_CDP_ENDPOINT`) to
   `http://localhost:9222`. The MCP connects to that running browser and reuses its session.
   CLI: `node screenshot.mjs <url> out.png --cdp http://localhost:9222`. (A normal Chrome must be
   relaunched with the debug port; use a separate `--user-data-dir` since Chrome locks the default
   profile.)

3. **Share just the session cookie.** Copy `grafana_session` from Chrome DevTools → Application →
   Cookies (it's httpOnly, so DevTools is the only place to read it):
   `node screenshot.mjs <url> out.png --cookie grafana_session=<value>`. Quickest but the value
   expires soonest.

Precedence when several are set: CDP endpoint → storage-state file → cookie → interactive login.

## Notes

- Screenshots are evidence for grading; keep them in `./previews/` and reference them by path.
- If panels are empty, the problem is usually the data source uid in the dashboard JSON not
  matching the provisioned data source, or the time range having no data. Fix the dashboard and
  re-provision rather than papering over it in the screenshot.
