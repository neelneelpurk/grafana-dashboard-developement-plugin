---
description: Convert an existing Grafana dashboard JSON into Foundation SDK code (TypeScript, Go, or Python), then verify the round-trip.
argument-hint: <path to dashboard JSON, exported model, or Grafana URL / uid> [typescript | go | python]
---

Convert the dashboard into Foundation SDK code. Input: **$ARGUMENTS** (a dashboard JSON file, an
exported model, or a Grafana URL / `uid`, with an optional target language).

1. **Get the dashboard JSON.**
   - **Local file / pasted model**: read it directly. If it's the
     `{ "dashboard": {...}, "meta": {...} }` export envelope, unwrap to the inner `dashboard`.
   - **Grafana URL or `uid`**: use the `dashboard-sync` skill to fetch the current JSON model via
     Playwright (the browser session authorizes the read — no token needed).

2. **Convert to code** with the `dashboard-to-code` skill, in the requested language (or the
   `sdk_language` plugin option; default TypeScript). Map every dashboard-level setting, panel,
   query, variable, threshold, and the row/grid layout to the builder API — read the
   `grafana-foundation-sdk` skill's `reference.md` so method names and import paths are exact.
   **Preserve the original `uid`.** Scaffold a project first if none exists
   (`skills/grafana-foundation-sdk/scripts/scaffold.sh <dir> <language>`).

3. **Verify the round-trip.** Run the generated program to emit JSON and diff it against the
   original model. Ignore benign differences (key order, SDK defaults, a dropped top-level `id`);
   fix the code for any semantic gap — a missing panel, changed query, or lost threshold.

4. **(Optional) Preview** with the `dashboard-preview` skill to confirm the rebuilt dashboard
   renders identically to the original.

Deliver: the generated SDK source, the regenerated JSON, and a note on any differences from the
original model — including anything that had no builder equivalent and couldn't be mapped.
