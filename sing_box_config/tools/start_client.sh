#!/usr/bin/env bash
# Start the sing-box service on the client.
set -euo pipefail
source "$(dirname "$0")/common.sh"
log "Starting client service ..."
client_exec "systemctl start $SERVICE_NAME"
setup_firewalld
log_ok "Client service started."
