#!/usr/bin/env bash
# Launch the official Grafana MCP server (github.com/grafana/mcp-grafana) when a Grafana
# token is configured. The Grafana MCP is the token-auth path for managing Grafana; with
# SSO-only / no token, use the grafana-api.sh CLI or Playwright instead (see grafana-admin skill).
#
# Needs the `mcp-grafana` binary on PATH, or Docker (image mcp/grafana). Stays inactive
# (exits) when no token is set — that is expected, not an error.
set -euo pipefail

URL="${GRAFANA_URL:-${CLAUDE_PLUGIN_OPTION_GRAFANA_URL:-http://localhost:3000}}"
TOKEN="${GRAFANA_TOKEN:-${CLAUDE_PLUGIN_OPTION_GRAFANA_TOKEN:-}}"

if [[ -z "$TOKEN" ]]; then
  echo "grafana MCP inactive: no Grafana token set (grafana_token). Use grafana-api.sh or Playwright." >&2
  exit 0
fi

export GRAFANA_URL="$URL"
export GRAFANA_SERVICE_ACCOUNT_TOKEN="$TOKEN"
export GRAFANA_API_KEY="$TOKEN"   # older mcp-grafana releases read this name

if command -v mcp-grafana >/dev/null 2>&1; then
  exec mcp-grafana
elif command -v docker >/dev/null 2>&1; then
  # On Docker Desktop, a localhost Grafana URL must be reachable as host.docker.internal.
  exec docker run -i --rm \
    -e GRAFANA_URL -e GRAFANA_SERVICE_ACCOUNT_TOKEN -e GRAFANA_API_KEY \
    --add-host host.docker.internal:host-gateway \
    mcp/grafana -t stdio
else
  echo "grafana MCP needs the 'mcp-grafana' binary or Docker. Skipping." >&2
  exit 0
fi
