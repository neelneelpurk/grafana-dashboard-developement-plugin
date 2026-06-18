#!/usr/bin/env bash
# Provision a dashboard JSON file into Grafana via the HTTP API.
# Usage: provision-dashboard.sh <dashboard.json> [folderUid]
#
# Reads Grafana connection from (in priority order):
#   - GRAFANA_URL / GRAFANA_TOKEN env vars
#   - CLAUDE_PLUGIN_OPTION_GRAFANA_URL / CLAUDE_PLUGIN_OPTION_GRAFANA_TOKEN (plugin userConfig)
#   - defaults: http://localhost:3000 with admin:admin basic auth
set -euo pipefail

FILE="${1:?usage: provision-dashboard.sh <dashboard.json> [folderUid]}"
FOLDER_UID="${2:-}"

URL="${GRAFANA_URL:-${CLAUDE_PLUGIN_OPTION_GRAFANA_URL:-http://localhost:3000}}"
TOKEN="${GRAFANA_TOKEN:-${CLAUDE_PLUGIN_OPTION_GRAFANA_TOKEN:-}}"

if [[ ! -f "$FILE" ]]; then
  echo "Dashboard file not found: $FILE" >&2
  exit 1
fi

# The SDK emits the dashboard model. The provisioning API expects it wrapped.
# If the file already has a top-level "dashboard" key, send as-is; otherwise wrap it.
if grep -q '"dashboard"' "$FILE" && grep -q '"overwrite"' "$FILE"; then
  PAYLOAD="$(cat "$FILE")"
else
  FOLDER_FRAGMENT=""
  [[ -n "$FOLDER_UID" ]] && FOLDER_FRAGMENT="\"folderUid\": \"$FOLDER_UID\","
  PAYLOAD="{ \"dashboard\": $(cat "$FILE"), ${FOLDER_FRAGMENT} \"overwrite\": true, \"message\": \"provisioned by grafana-dashboard-builder\" }"
fi

AUTH=(-u "admin:admin")
[[ -n "$TOKEN" ]] && AUTH=(-H "Authorization: Bearer $TOKEN")

echo "Provisioning $FILE -> $URL"
HTTP_CODE=$(curl -sS -o /tmp/grafana-provision-resp.json -w '%{http_code}' \
  -X POST "$URL/api/dashboards/db" \
  -H 'Content-Type: application/json' \
  "${AUTH[@]}" \
  -d "$PAYLOAD")

cat /tmp/grafana-provision-resp.json
echo
if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  SLUG_URL=$(grep -o '"url":"[^"]*"' /tmp/grafana-provision-resp.json | head -1 | sed 's/"url":"//; s/"//')
  echo "OK ($HTTP_CODE). View at: ${URL}${SLUG_URL}"
else
  echo "FAILED (HTTP $HTTP_CODE)" >&2
  exit 1
fi
