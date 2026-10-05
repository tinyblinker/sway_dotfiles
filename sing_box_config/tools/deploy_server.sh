#!/usr/bin/env bash
# Upload the server config and validate it with sing-box check.
set -euo pipefail
source "$(dirname "$0")/common.sh"

log "Deploying server config ..."
tmp=$(sops_decrypt_tmp "$SERVER_CONFIG_FILE")
server_upload "$tmp" "$SINGBOX_DIR/config.json"
rm -f "$tmp"
server_exec "$SERVER_BIN check -c $SINGBOX_DIR/config.json"
log_ok "Server config deployed and validated."
