# Changelog

All notable changes to this plugin are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions match the plugin
`version` in `.claude-plugin/plugin.json`.

## [0.2.0] - 2026-07-06

### Added

- Every skill in `skills/` can now be installed standalone with the
  [`skills`](https://www.npmjs.com/package/skills) CLI —
  `npx skills add neelneelpurk/grafana-dashboard-developement-plugin[/skills/<name>]` — no plugin
  install required. Documented in the README's "Install just the skills" section.
- `dashboard-quality-rubric`: a new rubric item (and a code-check step) flags repeated panel
  shapes that should have been factored into reusable functions instead of copy-pasted builder
  chains.

### Changed

- **Go output is now generated as reusable, parametrized panel builders instead of one long
  `main.go`.** `scripts/scaffold.sh <dir> go` now scaffolds a `panels/` package (`TimeSeries`,
  `CurrentValue`, `GoldenSignals`, `WithPanels` factory functions) alongside a thin `main.go` that
  composes dashboards from it. The `grafana-foundation-sdk` skill, its `reference.md`, the
  `dashboard-to-code` skill, and the `grafana-dashboard-architect` agent all now teach/require
  this pattern — the same panel/row shape should never be written twice.
- Every skill's references to its own or another skill's scripts are now self-relative
  (`scripts/x.sh`) or sibling-relative (`../grafana-foundation-sdk/scripts/x.sh`) instead of
  repo-root paths (`skills/<name>/scripts/x.sh`), so a skill still finds its scripts whether it's
  used as part of this plugin or installed standalone via `npx skills add`.
- README: added a top-level Quick Start, documented the `npx skills add` install path and its
  path-resolution convention.

## [0.1.0] - 2026-06-18

Initial release.

### Added

- `grafana-foundation-sdk` skill: build dashboards as code in TypeScript, Go, or Python; scaffold
  and provision scripts.
- `dashboard-to-code` skill: convert an existing dashboard JSON into Foundation SDK code (TS/Go/
  Python) with a round-trip check.
- `panel-selection-advisor` skill: map metrics to the right visualization.
- `dashboard-preview` skill: provision + screenshot with Playwright MCP, with a Playwright CLI
  fallback and support for reusing an OIDC/SSO-authenticated Chrome session.
- `dashboard-sync` skill: fetch/push dashboards through a browser session (no API token needed).
- `grafana-admin` skill: folder and dashboard lifecycle management, auth-based backend selection
  (Grafana MCP/CLI for tokens, Playwright for SSO).
- `dashboard-quality-rubric` skill: yes/no rubric that renders with Playwright, checks the code,
  and returns a PASS/FAIL verdict plus a "what to improve" summary.
- `grafana-dashboard-architect` and `dashboard-taste-critic` agents for the end-to-end build and
  independent review loops.
- `/create-dashboard`, `/update-dashboard`, `/convert-dashboard`, `/review-dashboard`,
  `/provision-dashboard`, `/grafana-admin` commands.
- Bundled Playwright MCP (with CLI script fallback) and the official Grafana MCP (token auth).
- `examples/observability-stack` and `examples/checkout-dashboard` for a runnable end-to-end demo.
