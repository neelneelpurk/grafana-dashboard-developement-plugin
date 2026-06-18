#!/usr/bin/env bash
# Capture a logged-in Grafana session into a Playwright storageState file.
# Opens a real browser; log into Grafana by hand, then CLOSE the window to save.
#
# Usage: capture-session.sh [grafana-login-url] [output.json]
#   defaults: http://localhost:3000/login  ->  grafana-auth.json
#
# Reuse the saved file by setting GRAFANA_STORAGE_STATE (or the grafana_storage_state
# plugin option) for the Playwright MCP, or pass it to screenshot.mjs --storage-state.
set -euo pipefail

URL="${1:-${GRAFANA_URL:-${CLAUDE_PLUGIN_OPTION_GRAFANA_URL:-http://localhost:3000}}}"
case "$URL" in */login) : ;; *) URL="${URL%/}/login" ;; esac
OUT="${2:-grafana-auth.json}"

echo "Opening a browser at $URL"
echo "Log into Grafana, then close the browser window to save the session to $OUT"
npx playwright codegen --save-storage="$OUT" "$URL"

if [[ -f "$OUT" ]]; then
  echo "Saved session to $OUT"
  echo "Use it with:  GRAFANA_STORAGE_STATE=\"$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")\""
  echo "or:           node screenshot.mjs <dashboard-url> out.png --storage-state \"$OUT\""
else
  echo "No session file was written (did the browser close without logging in?)." >&2
  exit 1
fi
