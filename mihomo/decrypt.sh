#!/usr/bin/env bash
set -euo pipefail

# Decrypt mihomo config.enc.yaml -> etc/mihomo/config.yaml with sops+age.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

log() {
  local lvl="$1"; shift
  case "$lvl" in
    ok)    printf '\033[32m[ok] %s\033[0m\n' "$*" ;;
    info)  printf '\033[36m==> %s\033[0m\n' "$*" ;;
    warn)  printf '\033[33m[warn] %s\033[0m\n' "$*" >&2 ;;
    error) printf '\033[31m[error] %s\033[0m\n' "$*" >&2 ;;
  esac
}

ENC="config.enc.yaml"
PLAIN="etc/mihomo/config.yaml"
KEY_FILE="age-key.txt"

[[ -f "${KEY_FILE}" ]] || { log error "age key not found: ${SCRIPT_DIR}/${KEY_FILE}"; exit 1; }
export SOPS_AGE_KEY_FILE="${SCRIPT_DIR}/${KEY_FILE}"

command -v sops >/dev/null 2>&1 || { log error "sops is not installed"; exit 1; }
[[ -f "${ENC}" ]] || { log error "encrypted config not found: ${ENC}"; exit 1; }

mkdir -p "$(dirname "${PLAIN}")"
sops --decrypt "${ENC}" > "${PLAIN}"

log ok "decrypted ${ENC} -> ${PLAIN}"
log info "deploy with ./deploy.sh (stows to /etc/mihomo)"
