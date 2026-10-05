#!/usr/bin/env bash
# Start the sing-box service on the server.
set -euo pipefail
source "$(dirname "$0")/common.sh"
log "Starting server service ..."
server_exec "systemctl start $SERVICE_NAME"
log_ok "Server service started."
