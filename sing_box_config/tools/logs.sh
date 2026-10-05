#!/usr/bin/env bash
# Show recent sing-box logs. Usage: logs.sh [server|client|both] [lines]
set -euo pipefail
source "$(dirname "$0")/common.sh"

which="${1:-both}"
lines="${2:-100}"

show_logs() {
  local label="$1" fn="$2"
  log "===== $label logs ====="
  "$fn" "journalctl -u $SERVICE_NAME -n $lines --no-pager"
}

case "$which" in
  server) show_logs "Server" server_exec ;;
  client) show_logs "Client" client_exec ;;
  *) show_logs "Server" server_exec; show_logs "Client" client_exec ;;
esac
