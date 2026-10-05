#!/usr/bin/env bash
# Uninstall sing-box from both hosts.
set -euo pipefail
source "$(dirname "$0")/common.sh"

read -r -p "Uninstall sing-box on both hosts? [y/N] " ans
if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
  log_warn "Cancelled."
  exit 0
fi

# Server: remove the GitHub binary, config and custom service.
log "===== Uninstalling Server $SERVER_HOST ====="
server_exec "systemctl stop $SERVICE_NAME 2>/dev/null || true; systemctl disable $SERVICE_NAME 2>/dev/null || true; rm -f /etc/systemd/system/$SERVICE_NAME.service; systemctl daemon-reload; rm -f $SERVER_BIN; rm -rf $SINGBOX_DIR"

# Client: remove the Arch packages, config and any leftover files.
log "===== Uninstalling Client $CLIENT_HOST ====="
client_exec "systemctl stop $SERVICE_NAME 2>/dev/null || true; systemctl disable $SERVICE_NAME 2>/dev/null || true; rm -f /etc/systemd/system/$SERVICE_NAME.service /usr/local/bin/sing-box; systemctl daemon-reload"
client_exec "pacman -R --noconfirm sing-box sing-geoip-rule-set sing-geosite-rule-set 2>/dev/null || true"

log_ok "Uninstall done."
