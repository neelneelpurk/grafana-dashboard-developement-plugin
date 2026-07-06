---
name: dashboard-to-code
description: Convert an existing Grafana dashboard JSON model into Grafana Foundation SDK code (TypeScript, Go, or Python). Use when the user has a dashboard JSON (a file, an exported model, or one fetched from a Grafana URL) and wants the equivalent maintainable as-code source — reverse-engineering panels, queries, variables, thresholds, and layout into the builder API so the dashboard can be version-controlled and edited as code.
---

# Convert a Grafana dashboard JSON into Foundation SDK code

Grafana dashboards are often hand-built in the UI and exported as JSON. That JSON is a flat,
verbose model that's painful to diff and maintain. This skill takes an existing dashboard JSON
and rebuilds it as **Foundation SDK code** so it becomes readable, reviewable, and editable as
code — the inverse of the `grafana-foundation-sdk` skill, which goes code → JSON.

Pick the output language from the user's request or the `sdk_language` plugin option
(`typescript`, `go`, or `python`); default to TypeScript. The generated code must round-trip:
building it back to JSON should reproduce the original dashboard.

## Getting the input JSON

- **Local file**: read the dashboard JSON directly.
- **Exported model**: the user may paste the model, or the `{ "dashboard": {...}, "meta": {...} }`
  envelope from `/api/dashboards/uid/<uid>`. Unwrap to the inner `dashboard` model.
- **Grafana URL / uid**: use the `dashboard-sync` skill to fetch the current JSON model through
  Playwright (the browser session authorizes the read — no token needed), then convert it.

## Workflow

1. **Parse the model.** Read the dashboard JSON and inventory it before writing any code:
   - Dashboard-level: `title`, `uid`, `tags`, `refresh`, `time`, `timezone`, `editable`,
     `templating.list` (variables), `links`, `annotations`.
   - `panels[]`: for each panel note `type`, `title`, `description`, `gridPos` (x/y/w/h),
     `datasource`, `targets[]` (queries), `fieldConfig` (units, min/max, thresholds, mappings,
     overrides), and panel-specific `options`. Rows are panels of `type: "row"` — preserve their
     grouping and any collapsed children.
2. **Map each element to a builder.** Translate the model into the builder API using the exact
   method names and import paths in the `grafana-foundation-sdk` skill's `reference.md` — read it
   first so names are exact rather than guessed. Map, in order:
   - Dashboard scaffold (`DashboardBuilder(title)` + `.uid()`, `.tags()`, `.refresh()`,
     `.time()`, `.timezone()`). **Preserve the original `uid`** so re-provisioning updates the
     same dashboard rather than creating a duplicate.
   - Each panel `type` → the matching panel package (`timeseries`, `stat`, `gauge`, `table`,
     `barchart`, …; see the reference's panel-type table). Set `.title()`, `.description()`,
     `.datasource()`, units, min/max, thresholds, and notable `options`.
   - Each target → the datasource query builder (`prometheus`, `loki`, …) with `.expr()` /
     `.legendFormat()` / `.refId()` as present.
   - `templating.list` entries → the matching variable builders
     (`QueryVariableBuilder`, `DatasourceVariableBuilder`, `CustomVariableBuilder`, …).
   - Layout: reproduce rows with `.withRow(...)` and panel sizes with `.span()` / `.height()`
     (derived from `gridPos.w` / `gridPos.h`).
3. **Factor out repeated panel shapes instead of transcribing each panel literally.** If the
   source JSON has the same panel shape multiple times with only titles/queries/units differing
   (e.g. a latency/traffic/errors row repeated per service, or the same table with different
   filters), don't emit one literal builder chain per occurrence — write one parametrized
   function and call it per occurrence. **For Go specifically**, put these factory functions in
   a `panels` package (see the `grafana-foundation-sdk` skill's `reference.md`, "Reusable Go
   panel builders") and have `main.go` compose the dashboard from calls into it; for TypeScript/
   Python, the equivalent is a small `panels.ts` / `panels.py` module of factory functions. This
   is a structural improvement over the source JSON (which has no notion of reuse) — call it out
   in the report alongside other tidy-ups.
4. **Prefer variables over hard-coded values.** When the JSON hard-codes a datasource uid that a
   template variable already covers, reference `${datasource}` instead — but only when it doesn't
   change behavior. Faithful conversion comes first; tidy-ups second, and call them out.
5. **Generate JSON and verify the round-trip.** Run the generated program to emit JSON
   (`npx tsx src/index.ts` / `go run .` / `python dashboard.py`) and diff it against the original
   model. Account for benign differences (key ordering, SDK-populated defaults, a dropped
   top-level `id`); investigate anything semantic — a missing panel, a changed query, a lost
   threshold — and fix the code until the dashboard is equivalent.
6. **Report what couldn't be mapped.** If a panel type, plugin, or option has no builder
   counterpart, keep the closest representation, leave a comment in the code, and tell the user.
   Don't silently drop configuration.

## Scaffolding

If there's no project to hold the generated code, scaffold one with the `grafana-foundation-sdk`
skill's helper, then write the converted dashboard into it:

```bash
../grafana-foundation-sdk/scripts/scaffold.sh <dir> <language>   # path relative to this skill's own directory
```

## Handing off

The output is SDK source plus the regenerated JSON. From here:
- **Provision & preview** with the `dashboard-preview` skill to confirm the rebuilt dashboard
  renders identically to the original.
- **Edit as code** going forward — subsequent changes run through the `grafana-foundation-sdk`
  skill and the `/update-dashboard` command against this source.

Deliver: the generated SDK source, the regenerated JSON, and a short note on any differences from
the original model (including anything that couldn't be mapped).
