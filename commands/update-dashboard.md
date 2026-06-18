---
description: Update an existing Grafana dashboard — fetch it (from a Grafana URL via Playwright, or a local file), apply changes, push it back, and re-check.
argument-hint: <grafana dashboard URL or local JSON/SDK source> — <what to change>
---

Update the dashboard. Input: **$ARGUMENTS** (a Grafana dashboard URL or a local file, followed by
the change to make).

1. **Get the current dashboard.**
   - If given a **Grafana URL** (e.g. `http://host/d/<uid>/<slug>`) or a bare `uid`: use the
     `dashboard-sync` skill to fetch the current JSON model through Playwright (the browser
     session authorizes the read — no token needed). Save it locally. If only a base
     `grafana_url` is known, navigate there with Playwright and open the target dashboard first.
   - If given a **local file**: use the Foundation SDK source if it exists (preferred — edit the
     code), otherwise the dashboard JSON.

2. **Apply the requested change** using the `grafana-foundation-sdk` skill:
   - When SDK source exists, edit the code (add/remove/retune panels, units, thresholds,
     variables, queries) and regenerate the JSON. This keeps the dashboard maintainable.
   - When you only have JSON (fetched from a URL), either reconstruct the relevant panels in SDK
     code or edit the JSON model directly for a targeted change. **Preserve the existing `uid`**
     so the update lands on the same dashboard instead of creating a duplicate.
   - If the change is ambiguous, ask which panels/metrics it should affect before editing.

3. **Push it back.** Use the `dashboard-sync` skill to push via Playwright (authenticated POST or
   the Import UI) when working from a Grafana URL, or
   `skills/grafana-foundation-sdk/scripts/provision-dashboard.sh` when you have a token/basic-auth.
   Keep the same `uid` with `overwrite: true`.

4. **Preview & re-check.** Render the updated dashboard with the `dashboard-preview` skill
   (Playwright screenshot), then run the `dashboard-quality-rubric` skill for a fresh PASS/FAIL
   verdict + "what to improve" summary. Iterate until the verdict is PASS.

Deliver: the updated SDK source and/or JSON, the new screenshot path, the dashboard URL, and the
verdict. You may delegate to the `grafana-dashboard-architect` agent.
