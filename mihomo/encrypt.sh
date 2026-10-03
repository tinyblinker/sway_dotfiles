#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

PLAIN="config.yaml"
ENC="config.enc.yaml"
KEY_FILE="age-key.txt"

# --- locate the age private key -------------------------------------------
if [[ ! -f "${KEY_FILE}" ]]; then
  echo "ERROR: age key not found: ${SCRIPT_DIR}/${KEY_FILE}" >&2
  echo "Generate one with:  age-keygen -o ${SCRIPT_DIR}/${KEY_FILE}" >&2
  echo "Then put its public key (age1...) into .sops.yaml." >&2
  exit 1
fi
export SOPS_AGE_KEY_FILE="${SCRIPT_DIR}/${KEY_FILE}"

# --- sanity checks ---------------------------------------------------------
command -v sops >/dev/null 2>&1 || { echo "ERROR: sops is not installed" >&2; exit 1; }
[[ -f "${PLAIN}" ]] || { echo "ERROR: plaintext config not found: ${PLAIN}" >&2; exit 1; }
[[ -f ".sops.yaml" ]] || { echo "ERROR: .sops.yaml not found in ${SCRIPT_DIR}" >&2; exit 1; }

# --- encrypt ---------------------------------------------------------------
sops --encrypt "${PLAIN}" > "${ENC}"

echo "OK: encrypted ${PLAIN} -> ${ENC}"
echo "    Sealed: the subscription 'url' + the two 'nameserver-policy' URLs."
