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
   → yes/no quality check        (dashboard-quality-rubric skill — renders + checks code)
   → apply the "what to improve" fixes and repeat until the verdict is PASS
```

## Components

| Type | Name | Purpose |
| --- | --- | --- |
| Skill | `grafana-foundation-sdk` | Build dashboards as code in **TypeScript, Go, or Python**; scaffold + provision scripts. |
| Skill | `panel-selection-advisor` | Map the metrics you want to track to the right visualization. |
| Skill | `dashboard-preview` | Provision to Grafana and screenshot with Playwright MCP/CLI. |
| Skill | `dashboard-sync` | Fetch an existing dashboard from a Grafana URL and push one back — via Playwright. |
| Skill | `grafana-admin` | Folders & dashboard lifecycle (create/move/delete) — Grafana MCP/CLI for token auth, Playwright for SSO. |
| Skill | `dashboard-quality-rubric` | Yes/no rubric: renders with Playwright + checks code, returns PASS/FAIL + what to improve. |
| Agent | `grafana-dashboard-architect` | End-to-end: design → build → preview → self-grade. |
| Agent | `dashboard-taste-critic` | Independent, honest review against the rubric. |
| Command | `/create-dashboard <what to monitor>` | Run the full build-and-verify loop. |
| Command | `/update-dashboard <url or file> — <change>` | Fetch (Playwright), edit, push back, re-check. |
| Command | `/review-dashboard <url / json / uid>` | Grade an existing dashboard (fetches from a URL via Playwright). |
| Command | `/provision-dashboard <json> [url] [api\|playwright]` | Push a dashboard to Grafana via Playwright or the API. |
| Command | `/grafana-admin <action> <args>` | Create/delete folders, move/delete dashboards. |
| MCP | `playwright` | Browser automation for rendering, fetching, pushing, and screenshots. |
| MCP | `grafana` | Official Grafana MCP for token-auth management (starts only when `grafana_token` is set). |
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
Two optional options let the Playwright browser reuse an existing Grafana login instead of
prompting each time — **this is how OIDC/SSO/SAML works**: you complete the SSO flow once in a
real browser and Playwright reuses that session (it never drives the identity provider).
`grafana_storage_state` is a saved session file (capture it with
`skills/dashboard-preview/scripts/capture-session.sh` — complete the full SSO + MFA, then close
the window); `grafana_cdp_endpoint` connects to a running Chrome you started with
`--remote-debugging-port` and logged into. See the `dashboard-preview` skill's "Reusing a Chrome
login" section.

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

## Choosing how to talk to Grafana

The plugin reaches Grafana two ways and picks based on **how you authenticate**:

| You have… | It uses | For |
| --- | --- | --- |
| An API/service-account token (or basic-auth user+pass) | **Grafana CLI** (`grafana-api.sh`) / **Grafana MCP** / the provision script | provisioning, folder & dashboard admin — fast, no browser |
| Only an **OIDC/SSO** login (or a browser session) | **Playwright** (browser session against the same-origin API) | fetch/push/admin without a token, plus all screenshots |

Both are built to run cleanly: the CLI uses bounded curl timeouts (fails fast on an unreachable
Grafana, no hangs) and portable flags; the Playwright scripts launch with `--no-sandbox` (works
as root / in containers), navigate on `domcontentloaded` with bounded waits (no hanging on live
dashboards), and the MCP version is pinned for quick, offline-resilient startup.

## Requirements

- Claude Code with plugin support; **bash** (the MCP launchers and helper scripts are bash —
  on Windows use WSL/Git Bash).
- **Node.js 18+** — for Playwright MCP and the Foundation SDK (TypeScript).
- **curl + python3** — used by the Grafana CLI (`grafana-api.sh`) and the provision script.
- Go 1.21+ or Python 3.9+ if you generate dashboards in those languages.
- For the bundled example stack: **Docker**. Otherwise your own Grafana + data source.
- Optional: an API token (`grafana_token`) to enable the Grafana MCP and token-auth CLI; the
  Grafana MCP additionally needs the `mcp-grafana` binary or Docker.

## Troubleshooting

- **CLI screenshot fallback** (`screenshot.mjs`) needs Playwright installed:
  `npm i -D playwright && npx playwright install chromium`. Prefer Playwright MCP, which is bundled.
- **Pin/upgrade Playwright MCP**: it defaults to a known-good version; set
  `PLAYWRIGHT_MCP_VERSION=latest` (or a specific version) to change it.
- **SSO logins**: capture a session once with
  `skills/dashboard-preview/scripts/capture-session.sh` and set `grafana_storage_state`, or use a
  live Chrome via `grafana_cdp_endpoint`. See the `dashboard-preview` skill.
- **Grafana MCP shows disconnected**: it only runs when `grafana_token` is set and the
  `mcp-grafana` binary or Docker is available — otherwise use the `grafana-api.sh` CLI or
  Playwright, which cover the same operations.

## License

MIT
