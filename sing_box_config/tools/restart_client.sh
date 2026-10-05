#!/usr/bin/env bash
# Restart the sing-box service on the client.
set -euo pipefail
source "$(dirname "$0")/common.sh"
log "Restarting client service ..."
client_exec "systemctl restart $SERVICE_NAME"
setup_firewalld
log_ok "Client service restarted."
