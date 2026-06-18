---
description: Run the yes/no quality & taste check on a Grafana dashboard and return a PASS/FAIL verdict plus what to improve.
argument-hint: <Grafana dashboard URL, path to dashboard JSON, a UID, or "current">
---

Review the Grafana dashboard: **$ARGUMENTS**

Run the `dashboard-quality-rubric` skill end to end — it does the whole thing itself:

1. Resolve the input to a dashboard:
   - A **Grafana dashboard URL** (e.g. `http://host/d/<uid>/<slug>`) or a base `grafana_url`:
     use the `dashboard-sync` skill to open it with Playwright and fetch the current JSON model
     through the browser session — no token needed. (This URL also serves as the render target.)
   - A **local JSON file** or exported dashboard: use it directly and ensure it's provisioned.
2. Render it with **Playwright MCP** and take a full-page screenshot — the visual rubric items
   are judged from the render, not the JSON.
3. Check the code/JSON for the correctness items.
4. Answer every yes/no rubric item with cited evidence, apply the verdict rule (PASS only if all
   critical items are Yes and ≤ 2 normal items are No), and produce the **PASS/FAIL** verdict
   plus the **"what to improve"** summary.
5. Offer to apply the fixes via the `grafana-foundation-sdk` skill and re-run the check.

Prefer delegating to the `dashboard-taste-critic` agent for an independent, honest review.
