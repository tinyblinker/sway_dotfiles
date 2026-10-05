#!/usr/bin/env bash
# Shared settings and helpers for the sing-box deploy scripts.
# Source this file from the other scripts: source "$(dirname "$0")/common.sh"

# ---- Remote hosts ----------------------------------------------------------
# Hosts are loaded from the encrypted secrets file (see below) and can be
# overridden interactively. Users, ports and sudo flags are fixed.
CLIENT_USER="shyweeds"
CLIENT_PORT=22
CLIENT_SUDO=1

SERVER_USER="root"
SERVER_PORT=22
SERVER_SUDO=0

# ---- sing-box settings -----------------------------------------------------
DOMAIN="proxy.liushuang21341254.xin"
SERVER_LISTEN_PORT=443
MIXED_LISTEN_PORT=7890
SERVER_BIN="/usr/local/bin/sing-box"
CLIENT_BIN="/usr/bin/sing-box"
SINGBOX_DIR="/etc/sing-box"
SERVICE_NAME="sing-box"
TUN_ADDRESS="172.19.0.1/30"
TUN_MTU=9000
SINGBOX_VERSION="1.14.2"
# Paths used inside the configs.
SERVER_CERT_PATH="$SINGBOX_DIR/cert.pem"
SERVER_KEY_PATH="$SINGBOX_DIR/key.pem"
# Client rule-set paths (provided by the Arch repo packages).
GEOIP_CN_SRS="/usr/share/sing-box/rule-set/geoip-cn.srs"
GEOSITE_CN_SRS="/usr/share/sing-box/rule-set/geosite-cn.srs"
# Remote rule-set URLs for the Android config (the app downloads them).
GEOIP_CN_URL="https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs"
GEOSITE_CN_URL="https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs"

# ---- Local paths -----------------------------------------------------------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_CONFIG_FILE="$BASE_DIR/client_config/config.json"
SERVER_CONFIG_FILE="$BASE_DIR/server_config/config.json"
ANDROID_CONFIG_DIR="$BASE_DIR/client_android_config"
ANDROID_CONFIG_FILE="$ANDROID_CONFIG_DIR/config.json"

# ---- Logging ----------------------------------------------------------------
log()      { echo -e "\033[36m[*]\033[0m $*"; }
log_ok()   { echo -e "\033[32m[+]\033[0m $*"; }
log_warn() { echo -e "\033[33m[!]\033[0m $*"; }
log_err()  { echo -e "\033[31m[x]\033[0m $*"; }
log_cmd()  { echo -e "\033[90m  >\033[0m $*" >&2; }

# ---- Secrets (SOPS + age) --------------------------------------------------
# age private key location (used by sops to decrypt).
SOPS_AGE_KEY_FILE="$BASE_DIR/secrets/key.txt"
export SOPS_AGE_KEY_FILE

# Decrypt and load hosts + passwords from secrets/secrets.yaml.
load_secrets() {
  local f="$BASE_DIR/secrets/secrets.yaml" dec
  [ -f "$f" ] || { log_err "Missing secrets file: $f"; return 1; }
  dec=$(sops -d "$f" 2>/dev/null)
  CLIENT_HOST=$(printf '%s\n' "$dec" | sed -n 's/^CLIENT_HOST: *//p')
  SERVER_HOST=$(printf '%s\n' "$dec" | sed -n 's/^SERVER_HOST: *//p')
  CLIENT_PASSWORD=$(printf '%s\n' "$dec" | sed -n 's/^CLIENT_PASSWORD: *//p')
  SERVER_PASSWORD=$(printf '%s\n' "$dec" | sed -n 's/^SERVER_PASSWORD: *//p')
}

# Load secrets once, then prompt to override the hosts (defaults from the file).
if [ -z "${_SECRETS_LOADED:-}" ]; then
  load_secrets
  if [ -t 0 ]; then
    read -r -p "Client host [$CLIENT_HOST]: " _ovr
    [ -n "$_ovr" ] && CLIENT_HOST="$_ovr"
    read -r -p "Server host [$SERVER_HOST]: " _ovr
    [ -n "$_ovr" ] && SERVER_HOST="$_ovr"
  fi
  _SECRETS_LOADED=1
  export _SECRETS_LOADED CLIENT_HOST SERVER_HOST CLIENT_PASSWORD SERVER_PASSWORD
fi

# Encrypt a config file in place with SOPS.
sops_encrypt() { sops -e -i "$1"; }

# Decrypt a SOPS-encrypted file to a temp file and print its path.
sops_decrypt_tmp() { local t; t=$(mktemp); sops -d "$1" > "$t"; printf '%s\n' "$t"; }

# ---- SSH helpers -----------------------------------------------------------
# Password auth uses SSH_ASKPASS (no sshpass needed) with setsid (no tty).
_mkaskpass() {
  local pass="$1" f
  f=$(mktemp)
  printf "#!/bin/sh\nprintf '%%s\\n' '%s'\n" "$pass" > "$f"
  chmod 700 "$f"
  printf '%s\n' "$f"
}

# Run one command on a remote host. Args: host user password port cmd
ssh_exec() {
  local host="$1" user="$2" pass="$3" port="$4" cmd="$5" askpass rc
  askpass=$(_mkaskpass "$pass")
  log_cmd "$user@$host $cmd"
  SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force \
    setsid ssh -p "$port" -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR \
      "$user@$host" "$cmd" 2>&1
  rc=$?
  rm -f "$askpass"
  return "$rc"
}

# Upload a file to a remote host. Args: src dst host user password port
scp_upload() {
  local src="$1" dst="$2" host="$3" user="$4" pass="$5" port="$6" askpass rc
  askpass=$(_mkaskpass "$pass")
  log_cmd "upload $src -> $user@$host:$dst"
  SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force \
    setsid scp -P "$port" -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
      "$src" "$user@$host:$dst" 2>&1
  rc=$?
  rm -f "$askpass"
  return "$rc"
}

# Run one command on the server (root).
server_exec() { ssh_exec "$SERVER_HOST" "$SERVER_USER" "$SERVER_PASSWORD" "$SERVER_PORT" "$1"; }

# Upload a file to the server.
server_upload() { scp_upload "$1" "$2" "$SERVER_HOST" "$SERVER_USER" "$SERVER_PASSWORD" "$SERVER_PORT"; }

# Run one command on the client (shyweeds + sudo).
client_exec() {
  local cmd="$1"
  if [ "$CLIENT_SUDO" = "1" ]; then
    cmd="echo '$CLIENT_PASSWORD' | sudo -S -p '' sh -c '$cmd'"
  fi
  ssh_exec "$CLIENT_HOST" "$CLIENT_USER" "$CLIENT_PASSWORD" "$CLIENT_PORT" "$cmd"
}

# Upload a file to the client (upload to /tmp first, then sudo move).
# The config is readable by the sing-box service user, so use mode 644.
client_upload() {
  local src="$1" dst="$2" tmp="/tmp/.sb_up_$RANDOM"
  scp_upload "$src" "$tmp" "$CLIENT_HOST" "$CLIENT_USER" "$CLIENT_PASSWORD" "$CLIENT_PORT" || return 1
  client_exec "install -m 644 $tmp $dst && rm -f $tmp"
}

# ---- Random helpers ---------------------------------------------------------
gen_uuid()    { cat /proc/sys/kernel/random/uuid; }
gen_ws_path() { echo "/ws-$(openssl rand -hex 12)"; }

# Write the systemd unit for the server (Ubuntu has no package) and enable it.
create_server_service() {
  local unit b64
  # Build the unit and base64-encode it to avoid quoting problems over SSH.
  unit=$(cat <<EOF
[Unit]
Description=sing-box (server)
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=$SERVER_BIN run -c $SINGBOX_DIR/config.json
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
)
  b64=$(printf '%s\n' "$unit" | base64 -w0)
  server_exec "echo $b64 | base64 -d > /etc/systemd/system/$SERVICE_NAME.service && systemctl daemon-reload && systemctl enable $SERVICE_NAME"
}

# Add the TUN interface to the trusted firewalld zone (client only).
setup_firewalld() {
  client_exec "firewall-cmd --state 2>/dev/null | grep -q running && { firewall-cmd --zone=trusted --add-interface=tun0 --permanent 2>/dev/null; firewall-cmd --reload 2>/dev/null; firewall-cmd --zone=trusted --add-interface=tun0 2>/dev/null; } || true"
  log_ok "firewalld: tun0 added to trusted zone (if firewalld is running)"
}
