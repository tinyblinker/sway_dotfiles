#!/usr/bin/env bash
set -euo pipefail

# Encrypt mihomo etc/mihomo/config.yaml -> config.enc.yaml with sops+age.
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

PLAIN="etc/mihomo/config.yaml"
ENC="config.enc.yaml"
KEY_FILE="age-key.txt"

if [[ ! -f "${KEY_FILE}" ]]; then
    log error "age key not found: ${SCRIPT_DIR}/${KEY_FILE}"
    log info "generate one with:  age-keygen -o ${SCRIPT_DIR}/${KEY_FILE}"
    log info "then put its public key (age1...) into .sops.yaml"
    exit 1
fi
export SOPS_AGE_KEY_FILE="${SCRIPT_DIR}/${KEY_FILE}"

command -v sops >/dev/null 2>&1 || { log error "sops is not installed"; exit 1; }
[[ -f "${PLAIN}" ]] || { log error "plaintext config not found: ${PLAIN}"; exit 1; }
[[ -f ".sops.yaml" ]] || { log error ".sops.yaml not found in ${SCRIPT_DIR}"; exit 1; }

sops --encrypt "${PLAIN}" > "${ENC}"

log ok "encrypted ${PLAIN} -> ${ENC}"
