# Grafana Dashboard Builder — Claude Code plugin

A Claude Code plugin to **design, generate, preview, and quality-grade Grafana dashboards as
code** using the [Grafana Foundation SDK](https://github.com/grafana/grafana-foundation-sdk)
(TypeScript, Go, or Python) and [Playwright](https://github.com/microsoft/playwright-mcp) for
rendering — **both the Playwright MCP and the Playwright CLI are supported**: the bundled MCP is
preferred, and the plugin falls back to the CLI scripts when MCP isn't available. It includes a
rubric-based quality-and-taste critic so dashboards are judged consistently, not by vibes.

## What it does

```
describe what to monitor
   → pick the right panels       (panel-selection-advisor skill)
   → build it as code            (grafana-foundation-sdk skill — TS / Go / Python)
   → provision + screenshot      (dashboard-preview skill — Playwright MCP or CLI)
   → yes/no quality check        (dashboard-quality-rubric skill — renders + checks code)
   → apply the "what to improve" fixes and repeat until the verdict is PASS
```

Already have a dashboard? Bring it into the as-code workflow:

```
existing dashboard JSON / URL
   → reverse it into SDK code    (dashboard-to-code skill — TS / Go / Python)
   → verify the round-trip       (regenerate JSON, diff against the original)
   → edit, preview, and grade    (from here it's the same loop as above)
```

## Components

| Type | Name | Purpose |
| --- | --- | --- |
| Skill | `grafana-foundation-sdk` | Build dashboards as code in **TypeScript, Go, or Python**; scaffold + provision scripts. |
| Skill | `dashboard-to-code` | Convert an existing dashboard **JSON → Foundation SDK code** (TS / Go / Python), with a round-trip check. |
| Skill | `panel-selection-advisor` | Map the metrics you want to track to the right visualization. |
| Skill | `dashboard-preview` | Provision to Grafana and screenshot with Playwright MCP/CLI. |
| Skill | `dashboard-sync` | Fetch an existing dashboard from a Grafana URL and push one back — via Playwright. |
| Skill | `grafana-admin` | Folders & dashboard lifecycle (create/move/delete) — Grafana MCP/CLI for token auth, Playwright for SSO. |
| Skill | `dashboard-quality-rubric` | Yes/no rubric: renders with Playwright + checks code, returns PASS/FAIL + what to improve. |
| Agent | `grafana-dashboard-architect` | End-to-end: design → build → preview → self-grade. |
| Agent | `dashboard-taste-critic` | Independent, honest review against the rubric. |
| Command | `/create-dashboard <what to monitor>` | Run the full build-and-verify loop. |
| Command | `/update-dashboard <url or file> — <change>` | Fetch (Playwright), edit, push back, re-check. |
| Command | `/convert-dashboard <json / url / uid> [language]` | Reverse an existing dashboard JSON into Foundation SDK code, verified by round-trip. |
| Command | `/review-dashboard <url / json / uid>` | Grade an existing dashboard (fetches from a URL via Playwright). |
| Command | `/provision-dashboard <json> [url] [api\|playwright]` | Push a dashboard to Grafana via Playwright or the API. |
| Command | `/grafana-admin <action> <args>` | Create/delete folders, move/delete dashboards. |
| MCP | `playwright` | Browser automation for rendering, fetching, pushing, and screenshots. Bundled MCP is preferred; the bundled Playwright CLI scripts (`scripts/`) are the fallback when MCP is unavailable. |
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

### Install just the skills (without the plugin)

Every skill under `skills/` is a self-contained [Agent Skill](https://github.com/anthropics/skills)
(`SKILL.md` + its own `scripts/`) and can be installed on its own with the
[`skills`](https://www.npmjs.com/package/skills) CLI, no plugin install required:

```bash
# Install every skill in this repo
npx skills add neelneelpurk/grafana-dashboard-developement-plugin

# Or install just one, e.g. only the Foundation SDK builder skill
npx skills add neelneelpurk/grafana-dashboard-developement-plugin/skills/grafana-foundation-sdk
```

Skills reference their own scripts with paths relative to their own directory (`scripts/x.sh`)
and reference each other with sibling-relative paths (`../grafana-foundation-sdk/scripts/x.sh`),
so both install paths work: the whole-repo install keeps every skill's siblings in place, and a
single-skill install still finds its own bundled scripts. A skill that depends on another skill
(e.g. `dashboard-to-code` calling into `grafana-foundation-sdk`'s scaffold script) needs that
sibling skill installed too — install the whole repo if you want everything wired up, or the
Playwright/Grafana MCP servers and slash commands, which are plugin-only and not part of any
individual skill.

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

## Requirements

- Claude Code with plugin support.
- Node.js 18+ (TypeScript / Playwright), Go 1.21+ or Python 3.9+ depending on chosen SDK language.
- Docker (for the bundled example stack) or your own Grafana + data source.

## License

MIT
