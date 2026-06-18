# Grafana Dashboard Builder — Claude Code plugin

A Claude Code plugin to **design, generate, preview, and quality-grade Grafana dashboards as
code** using the [Grafana Foundation SDK](https://github.com/grafana/grafana-foundation-sdk)
(TypeScript, Go, or Python) and [Playwright MCP](https://github.com/microsoft/playwright-mcp).
It includes a rubric-based quality-and-taste critic so dashboards are judged consistently, not
by vibes.

## What it does

```
describe what to monitor
   → pick the right panels       (panel-selection-advisor skill)
   → build it as code            (grafana-foundation-sdk skill — TS / Go / Python)
   → provision + screenshot      (dashboard-preview skill — Playwright MCP)
   → grade against a rubric      (dashboard-quality-rubric skill)
   → fix the weakest dimensions and repeat until Ship-ready (≥ 80/100)
```

## Components

| Type | Name | Purpose |
| --- | --- | --- |
| Skill | `grafana-foundation-sdk` | Build dashboards as code in **TypeScript, Go, or Python**; scaffold + provision scripts. |
| Skill | `panel-selection-advisor` | Map the metrics you want to track to the right visualization. |
| Skill | `dashboard-preview` | Provision to Grafana and screenshot with Playwright MCP/CLI. |
| Skill | `dashboard-quality-rubric` | Score a dashboard 0–100 across 8 weighted dimensions + give fixes. |
| Agent | `grafana-dashboard-architect` | End-to-end: design → build → preview → self-grade. |
| Agent | `dashboard-taste-critic` | Independent, honest review against the rubric. |
| Command | `/create-dashboard <what to monitor>` | Run the full build-and-verify loop. |
| Command | `/review-dashboard <json / uid / "current">` | Grade an existing dashboard. |
| MCP | `playwright` | Browser automation for rendering and screenshots. |
| Example | `examples/observability-stack` | Grafana + Prometheus + synthetic metrics to test against. |
| Example | `examples/checkout-dashboard` | A complete golden-signals dashboard built for that stack. |

## Install

This repo is both a plugin and a single-plugin marketplace.

```bash
# In Claude Code:
/plugin marketplace add neelneelpurk/grafana-dashboard-developement-plugin
/plugin install grafana-dashboard-builder@grafana-dashboard-marketplace
```

Or load it directly for a session: `claude --plugin-dir /path/to/this/repo`.

On enable you'll be prompted for `grafana_url`, `grafana_token`, and your preferred
`sdk_language` (typescript / go / python). These feed the provision script and code generation.

## Quick start

```bash
# 1. Bring up a local Grafana + Prometheus + sample metrics
cd examples/observability-stack && docker compose up -d

# 2. In Claude Code, build a dashboard
/create-dashboard the checkout service in my local Prometheus

# 3. Or grade one you already have
/review-dashboard ./checkout.json
```

The Foundation SDK builder API for all three languages, a panel/query/variable/threshold cheat
sheet, and common gotchas are in `skills/grafana-foundation-sdk/reference.md`. The grading
rubric is in `skills/dashboard-quality-rubric/rubric.md`.

## Requirements

- Claude Code with plugin support.
- Node.js 18+ (TypeScript / Playwright), Go 1.21+ or Python 3.9+ depending on chosen SDK language.
- Docker (for the bundled example stack) or your own Grafana + data source.

## License

MIT
