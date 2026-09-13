#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# deploy_software.sh
# Arch Linux software setup script, made from fish/bash history.
# It installs and removes packages with pacman, enables systemd
# services, and sets up the firewalld firewall.
# ============================================================

PKG=(sudo pacman)
FIREWALL=(sudo firewall-cmd)
SYSTEMCTL=(sudo systemctl)

section() { echo; echo "==> $*"; }

# ------------------------------------------------------------
# 1. Update the system
# ------------------------------------------------------------
section "Update system"
"${PKG[@]}" -Syu --noconfirm

# ------------------------------------------------------------
# 2. Install packages (by category)
# ------------------------------------------------------------

# Basic system tools
BASE_TOOLS=(
    which
    rsync
    bat
    calc
)

# Shell and terminal
SHELL_TERMINAL=(
    fish
    alacritty
)

# Sway desktop
SWAY_DESKTOP=(
    fuzzel          # app launcher
    waybar          # status bar
    swaync          # notification daemon
    swayosd         # on-screen display
    flameshot       # screenshot
    wl-clipboard    # wayland clipboard
    playerctl       # media control
)

# Chinese input method
INPUT_METHOD=(
    fcitx5-im
    fcitx5-chinese-addons
)

# Editor
EDITOR=(
    emacs-wayland
)

# Development tools
DEV_TOOLS=(
    git
    base-devel
    gcc
    gdb
    cmake
    make
    man
)

# Fonts
FONTS=(
    ttf-jetbrains-mono
    ttf-jetbrains-mono-nerd
    ttf-iosevka-nerd
)

# System monitor and hardware
SYSTEM_MONITOR=(
    fastfetch       # system info
    btop            # process/resource monitor
    rocm-smi-lib    # AMD GPU monitor
)

# Network and services
NETWORK=(
    openssh         # SSH server
    firefox         # web browser
    firewalld       # firewall
)

# Login manager (greetd + TUI)
GREETER=(
    greetd
    greetd-tuigreet
)

# Other tools
MISC=(
    libnotify
    stow
    flatpak
    opencode
)

section "Install basic system tools"
"${PKG[@]}" -S --noconfirm --needed "${BASE_TOOLS[@]}"

section "Install shell and terminal"
"${PKG[@]}" -S --noconfirm --needed "${SHELL_TERMINAL[@]}"

section "Install Sway desktop"
"${PKG[@]}" -S --noconfirm --needed "${SWAY_DESKTOP[@]}"

section "Install Chinese input method"
"${PKG[@]}" -S --noconfirm --needed "${INPUT_METHOD[@]}"

section "Install editor"
"${PKG[@]}" -S --noconfirm --needed "${EDITOR[@]}"

section "Install development tools"
"${PKG[@]}" -S --noconfirm --needed "${DEV_TOOLS[@]}"

section "Install fonts"
"${PKG[@]}" -S --noconfirm --needed "${FONTS[@]}"

section "Install system monitor and hardware tools"
"${PKG[@]}" -S --noconfirm --needed "${SYSTEM_MONITOR[@]}"

section "Install network and services"
"${PKG[@]}" -S --noconfirm --needed "${NETWORK[@]}"

section "Install login manager"
"${PKG[@]}" -S --noconfirm --needed "${GREETER[@]}"

section "Install other tools"
"${PKG[@]}" -S --noconfirm --needed "${MISC[@]}"

# ------------------------------------------------------------
# 3. Remove packages (by category)
# ------------------------------------------------------------

# Old login manager (replaced by greetd)
REMOVE_OLD_GREETER=(
    ly
)

# Old tools (replaced by alacritty/flameshot etc.)
REMOVE_OLD_TOOLS=(
    foot
    wmenu
    grim
    slurp
)

# Old editors (replaced by emacs)
REMOVE_OLD_EDITOR=(
    vim
    nano
)

section "Remove old login manager"
"${PKG[@]}" -Rns --noconfirm "${REMOVE_OLD_GREETER[@]}"

section "Remove old tools"
"${PKG[@]}" -Rns --noconfirm "${REMOVE_OLD_TOOLS[@]}"

section "Remove old editors"
"${PKG[@]}" -Rns --noconfirm "${REMOVE_OLD_EDITOR[@]}"

# ------------------------------------------------------------
# 4. Enable systemd services
# ------------------------------------------------------------

# System services
section "Enable system services"
"${SYSTEMCTL[@]}" enable --now sshd.service        # SSH server
"${SYSTEMCTL[@]}" enable greetd.service            # login manager
"${SYSTEMCTL[@]}" enable --now firewalld.service   # firewall

# ------------------------------------------------------------
# 5. Set up git
# ------------------------------------------------------------

section "Set up git"

git config --global user.name "shyweeds"
git config --global user.email "2149934895@qq.com"
git config --global gpg.format ssh
git config --global user.signingKey ~/.ssh/id_ed25519
git config --global commit.gpgSign true

# ------------------------------------------------------------
# 6. Generate an SSH key
# ------------------------------------------------------------

section "Generate SSH key"

# Generate only if the key does not already exist
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "2149934895@qq.com" -f "$HOME/.ssh/id_ed25519" -N ""
else
    echo "SSH key already exists: $HOME/.ssh/id_ed25519"
fi

echo
echo "Your SSH public key:"
cat "$HOME/.ssh/id_ed25519.pub"

# ------------------------------------------------------------
# 7. Set up the firewall (firewalld)
# ------------------------------------------------------------

section "Set up firewall"

# home zone: bind network interfaces
"${FIREWALL[@]}" --zone=home --change-interface=enp1s0
"${FIREWALL[@]}" --zone=home --change-interface=wlp2s0

# home zone: reject by default
"${FIREWALL[@]}" --zone=home --set-target=REJECT --permanent

# home zone: remove unneeded services
"${FIREWALL[@]}" --zone=home --remove-service=mdns
"${FIREWALL[@]}" --zone=home --remove-service=samba-client
"${FIREWALL[@]}" --zone=home --remove-service=ssh

# home zone: allow SSH only from the LAN
"${FIREWALL[@]}" --zone=home --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'

# trusted zone: bind Meta interface
"${FIREWALL[@]}" --zone=trusted --change-interface=Meta

# make the rules permanent and reload
"${FIREWALL[@]}" --runtime-to-permanent
"${FIREWALL[@]}" --reload

# show the config
"${FIREWALL[@]}" --zone=home --list-all
"${FIREWALL[@]}" --zone=trusted --list-all

echo
echo "==> Software setup done"
