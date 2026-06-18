#!/usr/bin/env bash
# Thin Grafana CLI over the HTTP API for folder/dashboard management.
# Use this when you have an API/service-account token or basic-auth credentials.
# (For SSO-only Grafana, drive the same endpoints through Playwright instead — see the skill.)
#
# Usage:
#   grafana-api.sh create-folder <title> [uid]
#   grafana-api.sh list-folders
#   grafana-api.sh get-dashboard <dashboard-uid> [outfile.json]
#   grafana-api.sh move-dashboard <dashboard-uid> <target-folder-uid>
#   grafana-api.sh delete-dashboard <dashboard-uid>
#   grafana-api.sh delete-folder <folder-uid>            # also deletes dashboards inside it
#
# Connection: GRAFANA_URL / CLAUDE_PLUGIN_OPTION_GRAFANA_URL (default http://localhost:3000)
# Auth:       GRAFANA_TOKEN / CLAUDE_PLUGIN_OPTION_GRAFANA_TOKEN  (Bearer), else
#             GRAFANA_USER + GRAFANA_PASSWORD                      (basic), else
#             admin/admin — for a LOCALHOST url only (the bundled stack); never sent to a
#             remote Grafana.
# Note: uses `curl --fail-with-body`; curl 7.76+ (2021) required.
set -euo pipefail

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

json_str() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

req() { # method path [data]
  local method="$1" path="$2" data="${3:-}"
  local args=(-sS --fail-with-body -X "$method" "${AUTH[@]}" -H 'Content-Type: application/json' "$URL$path")
  [[ -n "$data" ]] && args+=(--data-binary "$data")
  curl "${args[@]}"
}

action="${1:-}"
case "$action" in
  create-folder)
    title="${2:?usage: create-folder <title> [uid]}"; uid="${3:-}"
    body="{\"title\": $(json_str "$title")"
    [[ -n "$uid" ]] && body="$body, \"uid\": $(json_str "$uid")"
    body="$body}"
    req POST /api/folders "$body"; echo ;;

  list-folders)
    req GET /api/folders; echo ;;

  get-dashboard)
    duid="${2:?usage: get-dashboard <dashboard-uid> [outfile]}"; out="${3:-}"
    if [[ -n "$out" ]]; then req GET "/api/dashboards/uid/$duid" > "$out"; echo "Saved $out";
    else req GET "/api/dashboards/uid/$duid"; echo; fi ;;

  move-dashboard)
    duid="${2:?usage: move-dashboard <dashboard-uid> <target-folder-uid>}"
    folder="${3:?target-folder-uid required (use \"\" or 'general' for the root/General folder)}"
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    req GET "/api/dashboards/uid/$duid" > "$tmp"
    # Re-save the existing model into the target folder (overwrite keeps the same dashboard).
    payload="$(FOLDER="$folder" python3 - "$tmp" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
model = d["dashboard"]
folder = os.environ["FOLDER"]
folder = "" if folder.lower() == "general" else folder
out = {"dashboard": model, "overwrite": True,
       "message": "moved by grafana-dashboard-builder"}
if folder:
    out["folderUid"] = folder      # empty/omitted folderUid = General (root)
print(json.dumps(out))
PY
)"
    req POST /api/dashboards/db "$payload"; echo ;;

  delete-dashboard)
    duid="${2:?usage: delete-dashboard <dashboard-uid>}"
    req DELETE "/api/dashboards/uid/$duid"; echo ;;

  delete-folder)
    fuid="${2:?usage: delete-folder <folder-uid>}"
    echo "NOTE: deleting a folder also deletes the dashboards inside it." >&2
    req DELETE "/api/folders/$fuid"; echo ;;

  *)
    echo "Unknown action: '$action'" >&2
    grep -E '^#   grafana-api.sh' "$0" | sed 's/^#   /  /' >&2
    exit 1 ;;
esac
