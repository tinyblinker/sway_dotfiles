#!/usr/bin/env bash
# Install sing-box on the server: binary, self-signed cert, systemd service.
set -euo pipefail
source "$(dirname "$0")/common.sh"

log "Installing sing-box on the server ($SERVER_HOST) ..."

# Detect the architecture and map it to the release asset name.
arch=$(server_exec "uname -m" | tail -1)
case "$arch" in
  x86_64) arch="amd64" ;;
  aarch64) arch="arm64" ;;
  *) log_warn "Unknown arch '$arch', assuming amd64"; arch="amd64" ;;
esac

# Download, extract and install the binary.
url="https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/sing-box-$SINGBOX_VERSION-linux-$arch.tar.gz"
log "Downloading sing-box $SINGBOX_VERSION ($arch) ..."
server_exec "curl -fL -o /tmp/sb.tar.gz $url"
server_exec "rm -rf /tmp/sb && mkdir -p /tmp/sb && tar -xzf /tmp/sb.tar.gz -C /tmp/sb --strip-components=1"
server_exec "install -m 755 /tmp/sb/sing-box $SERVER_BIN && mkdir -p $SINGBOX_DIR"
server_exec "$SERVER_BIN version" >/dev/null

# Generate a self-signed certificate if it does not exist yet.
log "Ensuring self-signed certificate ..."
server_exec "if [ ! -f $SERVER_CERT_PATH ] || [ ! -f $SERVER_KEY_PATH ]; then openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout $SERVER_KEY_PATH -out $SERVER_CERT_PATH -days 3650 -subj /CN=$DOMAIN; fi"

# Create and enable the systemd service.
log "Creating systemd service ..."
create_server_service

log_ok "Server install done."
