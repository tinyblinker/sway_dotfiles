#!/usr/bin/env bash
# Show the sing-box status and version on both hosts.
set -euo pipefail
source "$(dirname "$0")/common.sh"

log "===== Server $SERVER_HOST ====="
log "Status: $(server_exec "systemctl is-active $SERVICE_NAME" | tail -1)"
server_exec "$SERVER_BIN version 2>/dev/null | head -1"

log "===== Client $CLIENT_HOST ====="
log "Status: $(client_exec "systemctl is-active $SERVICE_NAME" | tail -1)"
client_exec "$CLIENT_BIN version 2>/dev/null | head -1"
