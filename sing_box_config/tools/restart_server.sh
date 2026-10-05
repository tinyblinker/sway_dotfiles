#!/usr/bin/env bash
# Restart the sing-box service on the server.
set -euo pipefail
source "$(dirname "$0")/common.sh"
log "Restarting server service ..."
server_exec "systemctl restart $SERVICE_NAME"
log_ok "Server service restarted."
