#!/usr/bin/env bash
# Provision a dashboard JSON file into Grafana via the HTTP API.
# Usage: provision-dashboard.sh <dashboard.json> [folderUid]
#
# Auth (first that is set wins):
#   - GRAFANA_TOKEN / CLAUDE_PLUGIN_OPTION_GRAFANA_TOKEN  -> Bearer token
#   - GRAFANA_USER + GRAFANA_PASSWORD                     -> basic auth
#   - default for a LOCALHOST url only                    -> admin:admin (the bundled stack)
# A non-localhost URL with no token/credentials is an error — admin:admin is never sent to a
# remote Grafana.
# URL: GRAFANA_URL / CLAUDE_PLUGIN_OPTION_GRAFANA_URL, default http://localhost:3000
# Note: uses `curl --fail-with-body` semantics elsewhere; curl 7.76+ (2021) recommended.
set -euo pipefail

FILE="${1:?usage: provision-dashboard.sh <dashboard.json> [folderUid]}"
FOLDER_UID="${2:-}"

URL="${GRAFANA_URL:-${CLAUDE_PLUGIN_OPTION_GRAFANA_URL:-http://localhost:3000}}"
TOKEN="${GRAFANA_TOKEN:-${CLAUDE_PLUGIN_OPTION_GRAFANA_TOKEN:-}}"
G_USER="${GRAFANA_USER:-}"
G_PASS="${GRAFANA_PASSWORD:-}"

# Decide auth: token > explicit basic-auth > admin:admin (localhost only) > error.
is_localhost_url() { [[ "$1" =~ ^https?://(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?(/|$) ]]; }
if [[ -n "$TOKEN" ]]; then
  AUTH=(-H "Authorization: Bearer $TOKEN")
elif [[ -n "$G_USER" || -n "$G_PASS" ]]; then
  AUTH=(-u "${G_USER:-admin}:${G_PASS:-admin}")
elif is_localhost_url "$URL"; then
  AUTH=(-u "admin:admin")          # bundled local example stack only
else
  echo "No Grafana auth configured for $URL." >&2
  echo "Set GRAFANA_TOKEN (or the grafana_token option), or GRAFANA_USER + GRAFANA_PASSWORD." >&2
  echo "admin:admin is only assumed for a localhost Grafana." >&2
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "Dashboard file not found: $FILE" >&2
  exit 1
fi

# Build the request body. The provisioning API wants {"dashboard": <model>, "overwrite": true}.
# - If the file is already a wrapper (top-level "dashboard" key), pass it through.
# - Otherwise wrap the bare model and null out any stale "id" (an exported id that does not
#   exist on the target Grafana would be rejected).
# Prefer python3 for robust JSON handling; fall back to a shell heuristic if it is absent.
PAYLOAD_FILE="$(mktemp)"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

if command -v python3 >/dev/null 2>&1; then
  FOLDER_UID="$FOLDER_UID" python3 - "$FILE" > "$PAYLOAD_FILE" <<'PY'
import json, os, sys
doc = json.load(open(sys.argv[1]))
if isinstance(doc, dict) and "dashboard" in doc:
    payload = doc                      # already a wrapper, keep its keys
    # Still drop a stale id on the inner model so a fresh Grafana accepts it.
    if isinstance(payload.get("dashboard"), dict):
        payload["dashboard"].pop("id", None)
else:
    doc.pop("id", None)                # drop stale id so a fresh Grafana accepts it
    payload = {"dashboard": doc, "overwrite": True,
               "message": "provisioned by grafana-dashboard-builder"}
    folder = os.environ.get("FOLDER_UID")
    if folder:
        payload["folderUid"] = folder
json.dump(payload, sys.stdout)
PY
else
  # Heuristic fallback: treat as already-wrapped only if BOTH wrapper keys are present.
  if grep -q '"dashboard"' "$FILE" && grep -q '"overwrite"' "$FILE"; then
    cat "$FILE" > "$PAYLOAD_FILE"
  else
    FOLDER_FRAGMENT=""
    [[ -n "$FOLDER_UID" ]] && FOLDER_FRAGMENT="\"folderUid\": \"$FOLDER_UID\","
    printf '{ "dashboard": %s, %s "overwrite": true, "message": "provisioned by grafana-dashboard-builder" }' \
      "$(cat "$FILE")" "$FOLDER_FRAGMENT" > "$PAYLOAD_FILE"
  fi
fi

echo "Provisioning $FILE -> $URL"
RESP_FILE="$(mktemp)"
trap 'rm -f "$PAYLOAD_FILE" "$RESP_FILE"' EXIT
HTTP_CODE=$(curl -sS -o "$RESP_FILE" -w '%{http_code}' \
  -X POST "$URL/api/dashboards/db" \
  -H 'Content-Type: application/json' \
  "${AUTH[@]}" \
  --data-binary "@$PAYLOAD_FILE")

cat "$RESP_FILE"
echo
if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  SLUG_URL=$(grep -o '"url":"[^"]*"' "$RESP_FILE" | head -1 | sed 's/"url":"//; s/"//')
  echo "OK ($HTTP_CODE). View at: ${URL}${SLUG_URL}"
else
  echo "FAILED (HTTP $HTTP_CODE)" >&2
  exit 1
fi
