#!/usr/bin/env bash
set -euo pipefail

# Arch Linux post-install: packages, systemd, firewall, snapper, mihomo, rime.
PKG=(sudo pacman)
SYSTEMCTL=(sudo systemctl)
FIREWALL=(sudo firewall-cmd)

log() {
  local lvl="$1"; shift
  case "$lvl" in
    info)  printf '\033[36m==> %s\033[0m\n' "$*" ;;
    ok)    printf '\033[32m[ok] %s\033[0m\n' "$*" ;;
    warn)  printf '\033[33m[warn] %s\033[0m\n' "$*" >&2 ;;
    error) printf '\033[31m[error] %s\033[0m\n' "$*" >&2 ;;
  esac
}

install_pkgs() { local label="$1"; shift; log info "install $label"; "${PKG[@]}" -S --noconfirm --needed "$@"; }
remove_pkgs()  { local label="$1"; shift; log info "remove $label"; "${PKG[@]}" -Rns --noconfirm "$@"; }

# --- packages ---
BASE_TOOLS=(which rsync bat)
SHELL_TERMINAL=(fish alacritty)
SWAY_DESKTOP=(swayidle swaylock fuzzel waybar swaync swayosd polkit-gnome grim slurp wl-clipboard playerctl)
PORTAL=(xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr)
INPUT_METHOD=(fcitx5-im fcitx5-rime)
EDITOR=(emacs-wayland)
DEV_TOOLS=(git base-devel gcc gdb cmake make man rustup)
FONTS=(ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-iosevka-nerd)
SYSTEM_MONITOR=(fastfetch btop rocm-smi-lib)
NETWORK=(openssh firefox firewalld)
GREETER=(greetd greetd-tuigreet)
MISC=(libnotify stow flatpak ripgrep sops age)

log info "update system"
"${PKG[@]}" -Syu --noconfirm

install_pkgs "basic tools"    "${BASE_TOOLS[@]}"
install_pkgs "shell/terminal" "${SHELL_TERMINAL[@]}"
install_pkgs "sway desktop"   "${SWAY_DESKTOP[@]}"
install_pkgs "xdg portals"    "${PORTAL[@]}"
install_pkgs "chinese input"  "${INPUT_METHOD[@]}"
install_pkgs "editor"         "${EDITOR[@]}"
install_pkgs "dev tools"      "${DEV_TOOLS[@]}"
install_pkgs "fonts"          "${FONTS[@]}"
install_pkgs "system monitor" "${SYSTEM_MONITOR[@]}"
install_pkgs "network"        "${NETWORK[@]}"
install_pkgs "greeter"        "${GREETER[@]}"
install_pkgs "misc"           "${MISC[@]}"

# --- remove old packages ---
remove_pkgs "old greeter" ly
remove_pkgs "old tools"   foot wmenu
remove_pkgs "old editors" vim nano

# --- systemd services ---
log info "enable services"
"${SYSTEMCTL[@]}" enable --now sshd.service
"${SYSTEMCTL[@]}" enable greetd.service
"${SYSTEMCTL[@]}" enable --now firewalld.service

# --- default shell ---
log info "set default shell"
[ "$SHELL" = "/bin/fish" ] || [ "$SHELL" = "/usr/bin/fish" ] || chsh -s /bin/fish

# --- flatpak ---
log info "set up flatpak"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub

# --- rust ---
log info "set up rust"
rustup toolchain add stable
rustup component add rust-analyzer

# --- git ---
log info "set up git"
git config --global user.name "shyweeds"
git config --global user.email "2149934895@qq.com"
git config --global gpg.format ssh
git config --global user.signingKey ~/.ssh/id_ed25519
git config --global commit.gpgSign true

# --- ssh key ---
log info "generate ssh key"
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    log ok "ssh key exists"
else
    ssh-keygen -t ed25519 -C "2149934895@qq.com" -f "$HOME/.ssh/id_ed25519" -N ""
fi
log info "public key"
cat "$HOME/.ssh/id_ed25519.pub"

# --- firewall ---
log info "set up firewall"
"${FIREWALL[@]}" --zone=home --change-interface=enp1s0
"${FIREWALL[@]}" --zone=home --change-interface=wlp2s0
"${FIREWALL[@]}" --zone=home --set-target=REJECT --permanent
"${FIREWALL[@]}" --zone=home --remove-service=mdns
"${FIREWALL[@]}" --zone=home --remove-service=samba-client
"${FIREWALL[@]}" --zone=home --remove-service=ssh
"${FIREWALL[@]}" --zone=home --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'
"${FIREWALL[@]}" --zone=trusted --change-interface=Meta
"${FIREWALL[@]}" --runtime-to-permanent
"${FIREWALL[@]}" --reload
"${FIREWALL[@]}" --zone=home --list-all
"${FIREWALL[@]}" --zone=trusted --list-all

# --- snapper ---
log info "set up snapper"
"${PKG[@]}" -S --noconfirm --needed snapper
"${SYSTEMCTL[@]}" enable --now snapper-timeline.timer
"${SYSTEMCTL[@]}" enable --now snapper-cleanup.timer
[ -f /etc/snapper/configs/root ] || sudo snapper -c root create-config /
if [ -f /etc/snapper/configs/home ]; then sudo snapper -c home delete-config; fi

# --- mihomo (official GitHub package via pacman -U) ---
install_mihomo() {
    command -v curl >/dev/null 2>&1 || return 1
    local tag arch asset url tmp
    tag="$(curl -fsS -o /dev/null -w '%{redirect_url}' 'https://github.com/MetaCubeX/mihomo/releases/latest' | sed 's#.*/##')"
    [[ "$tag" == v* ]] || return 1
    case "$(uname -m)" in
        x86_64|amd64)  asset="mihomo-linux-amd64-v3-${tag}.pkg.tar.zst" ;;
        aarch64|arm64) asset="mihomo-linux-arm64-${tag}.pkg.tar.zst" ;;
        *) return 1 ;;
    esac
    url="https://github.com/MetaCubeX/mihomo/releases/download/${tag}/${asset}"
    tmp="$(mktemp -d)"
    log info "download $asset"
    curl -fL --retry 3 -o "${tmp}/${asset}" "${url}" || { rm -rf "$tmp"; return 1; }
    sudo pacman -U --noconfirm "${tmp}/${asset}"
    local rc=$?
    rm -rf "$tmp"
    return "$rc"
}

log info "install mihomo"
if install_mihomo; then
    log ok "mihomo installed"
else
    log warn "mihomo install failed; install manually then run ./deploy.sh:  paru -S mihomo"
fi

# --- rime (ice-rime + flypy via plum) ---
RIME_DIR="$HOME/.local/share/fcitx5/rime"
PLUM_DIR="$HOME/.local/share/plum"

install_rime() {
    command -v git >/dev/null 2>&1 || return 1
    if [ -d "${PLUM_DIR}/.git" ]; then
        (cd "${PLUM_DIR}" && git pull --ff-only) >/dev/null 2>&1 || true
    else
        mkdir -p "$(dirname "${PLUM_DIR}")"
        git clone --depth 1 https://github.com/rime/plum.git "${PLUM_DIR}" || return 1
    fi
    mkdir -p "${RIME_DIR}"
    rime_dir="${RIME_DIR}" bash "${PLUM_DIR}/rime-install" iDvel/rime-ice || return 1
    rime_dir="${RIME_DIR}" bash "${PLUM_DIR}/rime-install" "iDvel/rime-ice:others/recipes/config:schema=double_pinyin_flypy" || return 1
    rime_dir="${RIME_DIR}" bash "${PLUM_DIR}/rime-install" "iDvel/rime-ice:others/recipes/grammar:schema=double_pinyin_flypy" || true
    rime_dir="${RIME_DIR}" bash "${PLUM_DIR}/rime-install" "iDvel/rime-ice:others/recipes/reverse_tone:schema=double_pinyin_flypy" || true
}

log info "install rime (ice-rime + flypy)"
if install_rime; then
    log ok "rime installed to $RIME_DIR"
else
    log warn "rime install failed; install manually then run ./deploy.sh:  git clone https://github.com/rime/plum.git ~/.local/share/plum && cd ~/.local/share/plum && rime_dir=~/.local/share/fcitx5/rime bash rime-install iDvel/rime-ice"
fi

log ok "done"
