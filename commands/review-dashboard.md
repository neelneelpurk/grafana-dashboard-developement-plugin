---
description: Grade an existing Grafana dashboard against the quality & taste rubric and return a scorecard.
argument-hint: <path to dashboard JSON, a dashboard UID/URL, or "current">
---

Review and grade the Grafana dashboard: **$ARGUMENTS**

1. Resolve the input to a dashboard JSON: a file path, an exported dashboard, or a UID/URL to
   fetch from the configured Grafana.
2. Get a **rendered screenshot** using the `dashboard-preview` skill (provision if needed, then
   Playwright MCP). Readability and taste must be judged from the rendered result, not the JSON.
3. Apply the `dashboard-quality-rubric` skill: score all 8 weighted dimensions with cited
   evidence and produce the full scorecard (weighted table, overall /100, grade band, top fixes
   by impact, and what's already good).
4. Offer to apply the top fixes via the `grafana-foundation-sdk` skill and re-grade.

Prefer delegating to the `dashboard-taste-critic` agent for an independent, honest review.
