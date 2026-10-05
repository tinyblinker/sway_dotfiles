#!/usr/bin/env bash
# Install sing-box on the client from the Arch Linux official repo.
set -euo pipefail
source "$(dirname "$0")/common.sh"

log "Installing sing-box on the client ($CLIENT_HOST) from Arch repo ..."

# Stop any running service before cleanup.
client_exec "systemctl stop sing-box 2>/dev/null || true"

# Remove the old GitHub-installed binary and custom service if present.
client_exec "rm -f /usr/local/bin/sing-box"
client_exec "systemctl disable sing-box 2>/dev/null || true; rm -f /etc/systemd/system/sing-box.service"

# Install sing-box and the rule-set packages from the official repo.
client_exec "pacman -S --noconfirm sing-box sing-geoip-rule-set sing-geosite-rule-set"

# Enable the packaged service (runs as the sing-box user with caps).
client_exec "systemctl daemon-reload && systemctl enable sing-box"

log_ok "Client install done (Arch repo)."
