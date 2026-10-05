#!/usr/bin/env bash
# Upload the client config and validate it with sing-box check.
set -euo pipefail
source "$(dirname "$0")/common.sh"

log "Deploying client config ..."
tmp=$(sops_decrypt_tmp "$CLIENT_CONFIG_FILE")
client_upload "$tmp" "$SINGBOX_DIR/config.json"
rm -f "$tmp"
client_exec "$CLIENT_BIN check -c $SINGBOX_DIR/config.json"
log_ok "Client config deployed and validated."
