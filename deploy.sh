#!/usr/bin/env bash
set -euo pipefail

# stow directory (directory of this script)
STOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# packages to deploy to $HOME
HOME_PACKAGES=(sway waybar systemd alacritty systemd_user_environment)

# packages to deploy to the system root /
SYSTEM_PACKAGES=(greetd)

# check dependencies
if ! command -v stow >/dev/null 2>&1; then
    echo "error: GNU stow is not installed" >&2
    exit 1
fi

# deploy user configs to $HOME
stow --dir="$STOW_DIR" --target="$HOME" --restow "${HOME_PACKAGES[@]}"

# deploy system configs to / (/etc/greetd, requires root)
if [ "$(id -u)" -eq 0 ]; then
    stow --dir="$STOW_DIR" --target="/" --restow "${SYSTEM_PACKAGES[@]}"
else
    sudo stow --dir="$STOW_DIR" --target="/" --restow "${SYSTEM_PACKAGES[@]}"
fi

# reload and enable the registered systemd user services (the .service files in the package)
systemctl --user daemon-reload
for svc in "$STOW_DIR"/systemd/.config/systemd/user/*.service; do
    [ -e "$svc" ] || continue
    systemctl --user enable "$(basename "$svc")"
done

echo "deploy done"
