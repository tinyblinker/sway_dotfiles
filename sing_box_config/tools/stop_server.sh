#!/usr/bin/env bash
# Stop the sing-box service on the server.
set -euo pipefail
source "$(dirname "$0")/common.sh"
log "Stopping server service ..."
server_exec "systemctl stop $SERVICE_NAME"
log_ok "Server service stopped."
