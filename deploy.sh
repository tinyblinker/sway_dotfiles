#!/usr/bin/env bash
set -euo pipefail

# stow directory (directory of this script)
STOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# packages to deploy to $HOME
HOME_PACKAGES=(sway waybar systemd alacritty systemd_user_environment fuzzel swaync fcitx5)

# packages to deploy to the system root /
SYSTEM_PACKAGES=(greetd mihomo)

# check dependencies
if ! command -v stow >/dev/null 2>&1; then
    echo "error: GNU stow is not installed" >&2
    exit 1
fi

# ------------------------------------------------------------
# mihomo: deploy its config only when the kernel is installed.
# Its config is decrypted into etc/mihomo before stowing.
# ------------------------------------------------------------
if command -v mihomo >/dev/null 2>&1; then
    MIHOMO_OK=1
    "$STOW_DIR/mihomo/decrypt.sh"
else
    MIHOMO_OK=0
    echo "warning: mihomo is not installed; skipping its config deployment." >&2
    echo "         install it first, then re-run ./deploy.sh:" >&2
    echo "             ./deploy_software.sh            # installs mihomo from GitHub" >&2
    echo "             # or manually:  paru -S mihomo" >&2
fi

# deploy user configs to $HOME
stow --dir="$STOW_DIR" --target="$HOME" --restow "${HOME_PACKAGES[@]}"

# deploy system configs to / (/etc/greetd, /etc/mihomo, requires root)
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

# enable the mihomo systemd service (shipped with the GitHub/AUR package)
if [ "$MIHOMO_OK" -eq 1 ]; then
    if [ -f /usr/lib/systemd/system/mihomo.service ] || [ -f /etc/systemd/system/mihomo.service ]; then
        sudo systemctl daemon-reload
        sudo systemctl enable --now mihomo.service
    else
        echo "warning: no mihomo.service unit found; start it manually:" >&2
        echo "         sudo mihomo -d /etc/mihomo" >&2
    fi
fi

# reload and enable the registered systemd user services (the .service files in the package)
systemctl --user daemon-reload
for svc in "$STOW_DIR"/systemd/.config/systemd/user/*.service; do
    [ -e "$svc" ] || continue
    systemctl --user enable "$(basename "$svc")"
done

echo "deploy done"
