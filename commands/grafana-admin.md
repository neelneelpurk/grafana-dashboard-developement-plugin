---
description: Manage Grafana folders and dashboards — create/delete a folder, move a dashboard, delete a dashboard.
argument-hint: <create-folder|move-dashboard|delete-dashboard|delete-folder|list-folders> <args>
---

Perform the Grafana admin action: **$ARGUMENTS**

Use the `grafana-admin` skill. First **pick the backend by auth method**:

- A token or basic-auth credentials → the **Grafana MCP** (if running) or the
  `grafana-admin/scripts/grafana-api.sh` CLI.
- Only an **SSO/browser session** (no token) → **Playwright** against the same-origin API (reuse
  the logged-in session per the `dashboard-preview` skill).
- If the user named a method, use it.

Then run the requested operation (create-folder, move-dashboard, delete-folder,
delete-dashboard, list-folders). **Before any destructive action** (delete or move), confirm the
exact `uid`/title with the user, and warn that deleting a folder also deletes the dashboards
inside it. After the change, optionally open the result in the browser session and screenshot to
confirm.
