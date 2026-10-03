#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

ENC="config.enc.yaml"
PLAIN="config.yaml"
KEY_FILE="age-key.txt"

# --- locate the age private key -------------------------------------------
if [[ ! -f "${KEY_FILE}" ]]; then
  echo "ERROR: age key not found: ${SCRIPT_DIR}/${KEY_FILE}" >&2
  exit 1
fi
export SOPS_AGE_KEY_FILE="${SCRIPT_DIR}/${KEY_FILE}"

# --- sanity checks ---------------------------------------------------------
command -v sops >/dev/null 2>&1 || { echo "ERROR: sops is not installed" >&2; exit 1; }
[[ -f "${ENC}" ]] || { echo "ERROR: encrypted config not found: ${ENC}" >&2; exit 1; }

# --- decrypt ---------------------------------------------------------------
sops --decrypt "${ENC}" > "${PLAIN}"

echo "OK: decrypted ${ENC} -> ${PLAIN}"
echo "    Run mihomo with:  verge-mihomo -d . -f ${PLAIN}"
