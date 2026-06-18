#!/usr/bin/env bash
# Launch Playwright MCP, optionally wired to reuse a Grafana login session.
#
# Session reuse (first that is set wins):
#   - CDP endpoint  -> connect to an already-running Chrome (your live, logged-in session)
#       GRAFANA_CDP_ENDPOINT / CLAUDE_PLUGIN_OPTION_GRAFANA_CDP_ENDPOINT  (e.g. http://localhost:9222)
#   - storage state -> replay a saved logged-in session from a JSON file
#       GRAFANA_STORAGE_STATE / CLAUDE_PLUGIN_OPTION_GRAFANA_STORAGE_STATE (capture-session.sh makes it)
#   - neither       -> isolated browser; you log in each session when prompted
set -euo pipefail

CDP="${GRAFANA_CDP_ENDPOINT:-${CLAUDE_PLUGIN_OPTION_GRAFANA_CDP_ENDPOINT:-}}"
STATE="${GRAFANA_STORAGE_STATE:-${CLAUDE_PLUGIN_OPTION_GRAFANA_STORAGE_STATE:-}}"

if [[ -n "$CDP" ]]; then
  # Reuse the live browser; isolated/storage-state do not apply when connecting over CDP.
  exec npx @playwright/mcp@latest --cdp-endpoint "$CDP"
elif [[ -n "$STATE" ]]; then
  exec npx @playwright/mcp@latest --isolated --storage-state "$STATE"
else
  exec npx @playwright/mcp@latest --isolated
fi
