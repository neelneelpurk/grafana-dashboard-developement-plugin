---
name: grafana-admin
description: Manage Grafana folders and dashboard lifecycle — create a folder, move a dashboard between folders, delete a folder, delete a dashboard, list folders. Use when the user asks to organize, move, rename, or remove Grafana folders/dashboards. Chooses between the Grafana MCP / CLI (token auth) and Playwright (SSO / browser session) based on how the user authenticates.
---

# Grafana folder & dashboard administration

Create/delete folders, move dashboards between folders, and delete dashboards. There are two
backends; **pick by auth method** (and honor any explicit user preference):

## Choose the backend (by auth)

| Situation | Use | Why |
| --- | --- | --- |
| An API token / service-account token, or basic-auth username+password | **Grafana MCP** (if running) or the **`grafana-api.sh` CLI** | Direct HTTP API — fast, scriptable, no browser. The bundled Grafana MCP starts only when `grafana_token` is set. |
| **OIDC/SSO/SAML** or only a logged-in **browser session** (no token) | **Playwright** against the same-origin API | The session cookie authorizes API calls from the page; no token needed and no driving the IdP. |
| User explicitly asks for one method | That method | User guidance wins. |

Rule of thumb: **token → MCP/CLI; SSO/browser → Playwright.** If you have a token, prefer it
(simplest). If the only way in is an interactive SSO login, use the Playwright session (see the
`dashboard-preview` / `dashboard-sync` skills for capturing/reusing that session).

Destructive actions (delete folder/dashboard, move) are hard to undo — confirm the target
`uid`/title with the user before running them, and note that **deleting a folder also deletes the
dashboards inside it**.

---

## Backend A — Grafana CLI (`grafana-api.sh`) — token or basic auth

`scripts/grafana-api.sh <action> …` (path relative to this skill's own directory; reads
`grafana_url`/`grafana_token` plugin options, or `GRAFANA_URL`/`GRAFANA_TOKEN`, or
`GRAFANA_USER`/`GRAFANA_PASSWORD`):

```bash
grafana-api.sh create-folder "Team SRE"            # optional 2nd arg = folder uid
grafana-api.sh list-folders
grafana-api.sh move-dashboard <dashboard-uid> <target-folder-uid>   # "general" = root
grafana-api.sh delete-dashboard <dashboard-uid>
grafana-api.sh delete-folder <folder-uid>          # also deletes dashboards within
```

## Backend B — Grafana MCP — token

When `grafana_token` is set, the bundled **grafana** MCP server (official
`github.com/grafana/mcp-grafana`) is available. Use its tools for search/get/update operations
and folder management where exposed (e.g. search dashboards, get/update a dashboard, list/create
folders). For any operation its tools don't cover, fall back to `grafana-api.sh`. The MCP needs
the `mcp-grafana` binary or Docker; if neither is present it stays inactive and you use the CLI.

## Backend C — Playwright — SSO / browser session

When the only auth is an interactive SSO login, open Grafana with **Playwright MCP** (reuse a
captured/live session per the `dashboard-preview` skill) and call the same REST endpoints through
the page with `browser_evaluate` — the logged-in session cookie authorizes them:

```js
// Create a folder
async (title) => (await fetch('/api/folders', {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ title }),
})).json()

// Move a dashboard: fetch it, then re-save into the target folder
async ([uid, folderUid]) => {
  const cur = await (await fetch(`/api/dashboards/uid/${uid}`)).json();
  const body = { dashboard: cur.dashboard, overwrite: true };
  if (folderUid && folderUid !== 'general') body.folderUid = folderUid;
  return (await fetch('/api/dashboards/db', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })).json();
}

// Delete a dashboard
async (uid) => (await fetch(`/api/dashboards/uid/${uid}`, { method: 'DELETE' })).json()

// Delete a folder (also deletes its dashboards)
async (fuid) => (await fetch(`/api/folders/${fuid}`, { method: 'DELETE' })).json()
```

Pass the arguments to `browser_evaluate`. Alternatively use the Grafana UI flows (New → Folder;
dashboard settings → move; folder/dashboard → Delete) by clicking through with Playwright — handy
when you also want to confirm the result visually.

---

## Reference: the underlying API

| Operation | Method + path | Notes |
| --- | --- | --- |
| Create folder | `POST /api/folders` `{title, uid?}` | Returns the new folder's `uid`. |
| List folders | `GET /api/folders` | |
| Move dashboard | `POST /api/dashboards/db` `{dashboard, folderUid, overwrite:true}` | Re-save the existing model; omit/empty `folderUid` = General. |
| Delete dashboard | `DELETE /api/dashboards/uid/<uid>` | |
| Delete folder | `DELETE /api/folders/<uid>` | Deletes dashboards inside it too. |

After any change, you can verify with the `dashboard-preview` skill (open the folder/dashboard in
the browser session and screenshot).
