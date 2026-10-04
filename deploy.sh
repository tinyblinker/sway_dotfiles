#!/usr/bin/env bash
set -euo pipefail

# Deploy configs to $HOME and / via GNU Stow, then enable services.
STOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_PACKAGES=(sway waybar systemd alacritty systemd_user_environment fuzzel swaync)
SYSTEM_PACKAGES=(greetd mihomo)

log() {
  local lvl="$1"; shift
  case "$lvl" in
    info)  printf '\033[36m==> %s\033[0m\n' "$*" ;;
    ok)    printf '\033[32m[ok] %s\033[0m\n' "$*" ;;
    warn)  printf '\033[33m[warn] %s\033[0m\n' "$*" >&2 ;;
    error) printf '\033[31m[error] %s\033[0m\n' "$*" >&2 ;;
  esac
}

command -v stow >/dev/null 2>&1 || { log error "GNU stow is not installed"; exit 1; }

# Deploy mihomo only when its kernel is installed.
if command -v mihomo >/dev/null 2>&1; then
    MIHOMO_OK=1
    "$STOW_DIR/mihomo/decrypt.sh"
else
    MIHOMO_OK=0
    log warn "mihomo not installed; skipping its config (run ./deploy_software.sh or paru -S mihomo)"
fi

stow --dir="$STOW_DIR" --target="$HOME" --restow "${HOME_PACKAGES[@]}"

if [ "$(id -u)" -eq 0 ]; then
    rm -rf /etc/greetd
    if [ "$MIHOMO_OK" -eq 1 ]; then
        rm -rf /etc/mihomo
        stow --dir="$STOW_DIR" --target="/" --restow "${SYSTEM_PACKAGES[@]}"
    else
        stow --dir="$STOW_DIR" --target="/" --restow greetd
    fi
else
    sudo rm -rf /etc/greetd
    if [ "$MIHOMO_OK" -eq 1 ]; then
        sudo rm -rf /etc/mihomo
        sudo stow --dir="$STOW_DIR" --target="/" --restow "${SYSTEM_PACKAGES[@]}"
    else
        sudo stow --dir="$STOW_DIR" --target="/" --restow greetd
    fi
fi

if [ "$MIHOMO_OK" -eq 1 ]; then
    if [ -f /usr/lib/systemd/system/mihomo.service ] || [ -f /etc/systemd/system/mihomo.service ]; then
        sudo systemctl daemon-reload
        sudo systemctl enable --now mihomo.service
    else
        log warn "no mihomo.service found; run manually: sudo mihomo -d /etc/mihomo"
    fi
fi

systemctl --user daemon-reload
for svc in "$STOW_DIR"/systemd/.config/systemd/user/*.service; do
    [ -e "$svc" ] || continue
    systemctl --user enable "$(basename "$svc")"
done

log ok "deploy done"
