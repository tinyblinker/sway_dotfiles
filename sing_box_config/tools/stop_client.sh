#!/usr/bin/env bash
# Stop the sing-box service on the client.
set -euo pipefail
source "$(dirname "$0")/common.sh"
log "Stopping client service ..."
client_exec "systemctl stop $SERVICE_NAME"
log_ok "Client service stopped."
