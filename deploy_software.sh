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
)

# Shell and terminal
SHELL_TERMINAL=(
    fish
    alacritty
)

# Sway desktop
SWAY_DESKTOP=(
    swayidle        # idle management (auto lock / screen off)
    swaylock        # screen locker
    fuzzel          # app launcher
    waybar          # status bar
    swaync          # notification daemon
    swayosd         # on-screen display
    polkit-gnome    # PolicyKit authentication agent
    grim            # screenshot capture
    slurp           # screenshot region selection
    wl-clipboard    # wayland clipboard
    playerctl       # media control
)

# XDG desktop portals (screen capture / file dialogs for flatpak etc.)
PORTAL=(
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
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
    rustup
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
    ripgrep
)

section "Install basic system tools"
"${PKG[@]}" -S --noconfirm --needed "${BASE_TOOLS[@]}"

section "Install shell and terminal"
"${PKG[@]}" -S --noconfirm --needed "${SHELL_TERMINAL[@]}"

section "Install Sway desktop"
"${PKG[@]}" -S --noconfirm --needed "${SWAY_DESKTOP[@]}"

section "Install XDG desktop portals"
"${PKG[@]}" -S --noconfirm --needed "${PORTAL[@]}"

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

# Old tools (replaced by alacritty/fuzzel etc.)
REMOVE_OLD_TOOLS=(
    foot
    wmenu
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
# 5. Set the default shell to fish
# ------------------------------------------------------------

section "Set default shell to fish"
if [ "$SHELL" != "/bin/fish" ] && [ "$SHELL" != "/usr/bin/fish" ]; then
    chsh -s /bin/fish
else
    echo "Default shell is already fish"
fi

# ------------------------------------------------------------
# 6. Set up flatpak repositories
# ------------------------------------------------------------

section "Set up flatpak repositories"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub

# ------------------------------------------------------------
# 7. Set up Rust (rustup)
# ------------------------------------------------------------

section "Set up Rust"
rustup toolchain add stable
rustup component add rust-analyzer

# ------------------------------------------------------------
# 8. Set up git
# ------------------------------------------------------------

section "Set up git"

git config --global user.name "shyweeds"
git config --global user.email "2149934895@qq.com"
git config --global gpg.format ssh
git config --global user.signingKey ~/.ssh/id_ed25519
git config --global commit.gpgSign true

# ------------------------------------------------------------
# 9. Generate an SSH key
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
# 10. Set up the firewall (firewalld)
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

# ------------------------------------------------------------
# 11. Set up snapper (Btrfs snapshots, excluding /home)
# ------------------------------------------------------------

section "Set up snapper"

# Install snapper if it is not already present.
"${PKG[@]}" -S --noconfirm --needed snapper

# Enable periodic timeline snapshots and their cleanup.
"${SYSTEMCTL[@]}" enable --now snapper-timeline.timer
"${SYSTEMCTL[@]}" enable --now snapper-cleanup.timer

# Create the root config (snapshots of /) if it does not exist yet.
# /home is a separate Btrfs subvolume, so it is automatically excluded
# from snapshots of /.
if [ ! -f /etc/snapper/configs/root ]; then
    sudo snapper -c root create-config /
fi

# Do not snapshot /home: remove its dedicated config (and all its
# snapshots) if it is present, so /home is excluded from backups.
if [ -f /etc/snapper/configs/home ]; then
    sudo snapper -c home delete-config
fi

echo
echo "==> Software setup done"
