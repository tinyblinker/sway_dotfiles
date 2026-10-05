#!/usr/bin/env bash
# Generate client and server config.json with a fresh UUID and WS path.
set -euo pipefail
source "$(dirname "$0")/common.sh"

uuid=$(gen_uuid)
ws_path=$(gen_ws_path)

log "Generating config files ..."
mkdir -p "$BASE_DIR/client_config" "$BASE_DIR/server_config" "$ANDROID_CONFIG_DIR"

# Server config: VLESS + WebSocket + TLS on port 443 (self-signed cert).
cat > "$SERVER_CONFIG_FILE" <<EOF
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "listen_port": $SERVER_LISTEN_PORT,
      "users": [ { "uuid": "$uuid" } ],
      "tls": {
        "enabled": true,
        "certificate_path": "$SERVER_CERT_PATH",
        "key_path": "$SERVER_KEY_PATH"
      },
      "transport": {
        "type": "ws",
        "path": "$ws_path",
        "headers": { "Host": "$DOMAIN" }
      }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ]
}
EOF

# Client config: TUN global proxy + mixed proxy, with DNS hijack and split routing.
cat > "$CLIENT_CONFIG_FILE" <<EOF
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "type": "udp", "tag": "local", "server": "223.5.5.5" },
      { "type": "https", "tag": "remote", "server": "1.1.1.1", "detour": "proxy" }
    ],
    "rules": [
      { "domain": [ "$DOMAIN" ], "action": "route", "server": "local" },
      { "rule_set": "geosite-cn", "action": "route", "server": "local" }
    ],
    "final": "remote",
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "address": [ "$TUN_ADDRESS" ],
      "mtu": $TUN_MTU,
      "auto_route": true,
      "strict_route": false,
      "stack": "system"
    },
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": $MIXED_LISTEN_PORT
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "$DOMAIN",
      "server_port": $SERVER_LISTEN_PORT,
      "uuid": "$uuid",
      "tls": { "enabled": true, "server_name": "$DOMAIN" },
      "transport": {
        "type": "ws",
        "path": "$ws_path",
        "headers": { "Host": "$DOMAIN" }
      },
      "domain_resolver": { "server": "local" }
    },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "default_domain_resolver": { "server": "local" },
    "rule_set": [
      { "type": "local", "tag": "geoip-cn", "format": "binary", "path": "$GEOIP_CN_SRS" },
      { "type": "local", "tag": "geosite-cn", "format": "binary", "path": "$GEOSITE_CN_SRS" }
    ],
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      { "ip_is_private": true, "outbound": "direct" },
      { "rule_set": "geoip-cn", "outbound": "direct" },
      { "rule_set": "geosite-cn", "outbound": "direct" },
      { "outbound": "proxy" }
    ],
    "auto_detect_interface": true
  }
}
EOF

# Android config: no TUN/mixed inbound (the app uses the system VPN),
# remote rule-sets (the app downloads them), no auto_detect_interface.
cat > "$ANDROID_CONFIG_FILE" <<EOF
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "type": "udp", "tag": "local", "server": "223.5.5.5" },
      { "type": "https", "tag": "remote", "server": "1.1.1.1", "detour": "proxy" }
    ],
    "rules": [
      { "domain": [ "$DOMAIN" ], "action": "route", "server": "local" },
      { "rule_set": "geosite-cn", "action": "route", "server": "local" }
    ],
    "final": "remote",
    "strategy": "ipv4_only"
  },
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "$DOMAIN",
      "server_port": $SERVER_LISTEN_PORT,
      "uuid": "$uuid",
      "tls": { "enabled": true, "server_name": "$DOMAIN" },
      "transport": {
        "type": "ws",
        "path": "$ws_path",
        "headers": { "Host": "$DOMAIN" }
      },
      "domain_resolver": { "server": "local" }
    },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "default_domain_resolver": { "server": "local" },
    "rule_set": [
      { "type": "remote", "tag": "geoip-cn", "format": "binary", "url": "$GEOIP_CN_URL" },
      { "type": "remote", "tag": "geosite-cn", "format": "binary", "url": "$GEOSITE_CN_URL" }
    ],
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      { "ip_is_private": true, "outbound": "direct" },
      { "rule_set": "geoip-cn", "outbound": "direct" },
      { "rule_set": "geosite-cn", "outbound": "direct" },
      { "outbound": "proxy" }
    ]
  }
}
EOF

log_ok "Server config: $SERVER_CONFIG_FILE"
log_ok "Client config: $CLIENT_CONFIG_FILE"
log_ok "Android config: $ANDROID_CONFIG_FILE"
log "UUID: $uuid"
log "WS path: $ws_path"

# Encrypt uuid/path values with SOPS so the files are safe to commit.
sops_encrypt "$SERVER_CONFIG_FILE"
sops_encrypt "$CLIENT_CONFIG_FILE"
sops_encrypt "$ANDROID_CONFIG_FILE"
log_ok "Encrypted uuid/path values for git (structure stays visible)"
