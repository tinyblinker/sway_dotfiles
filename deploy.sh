#!/usr/bin/env bash
# Single entry point: deploy configs, bootstrap the system, switch hosts,
# and manage the encrypted mihomo config.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIHOMO_DIR="$ROOT/mihomo"

# Machine-specific knobs; override from the environment when needed.
WIRED_IF="${WIRED_IF:-enp1s0}"
WIRELESS_IF="${WIRELESS_IF:-wlp2s0}"
VPN_IF="${VPN_IF:-Meta}"

if [ "$(id -u)" -eq 0 ]; then
    SUDO=()
else
    SUDO=(sudo)
fi

log() {
    local lvl="$1"; shift
    case "$lvl" in
        info)  printf '\033[36m==> %s\033[0m\n' "$*" ;;
        ok)    printf '\033[32m[ok] %s\033[0m\n' "$*" ;;
        warn)  printf '\033[33m[warn] %s\033[0m\n' "$*" >&2 ;;
        error) printf '\033[31m[error] %s\033[0m\n' "$*" >&2 ;;
    esac
}

die() { log error "$*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is not installed"; }

usage() {
    cat <<'EOF'
usage: ./deploy.sh [command]

commands:
  config        stow configs and enable services (default)
  software      install packages and set up the system (Arch Linux)
  switch HOST   point sway/alacritty symlinks at HOST (e.g. mini_pc)
  encrypt       encrypt mihomo/etc/mihomo/config.yaml -> mihomo/config.enc.yaml
  decrypt       decrypt mihomo/config.enc.yaml -> mihomo/etc/mihomo/config.yaml
  help          show this help
EOF
}

# --- mihomo config encryption -------------------------------------------------

mihomo_decrypt() {
    need sops
    [ -f "$MIHOMO_DIR/age-key.txt" ] || die "age key not found: $MIHOMO_DIR/age-key.txt"
    [ -f "$MIHOMO_DIR/config.enc.yaml" ] || die "encrypted config not found: $MIHOMO_DIR/config.enc.yaml"

    mkdir -p "$MIHOMO_DIR/etc/mihomo"
    local tmp
    tmp="$(mktemp)"
    if ! ( cd "$MIHOMO_DIR" && SOPS_AGE_KEY_FILE="$MIHOMO_DIR/age-key.txt" \
           sops --decrypt config.enc.yaml ) > "$tmp"; then
        rm -f "$tmp"
        die "failed to decrypt mihomo config"
    fi
    mv "$tmp" "$MIHOMO_DIR/etc/mihomo/config.yaml"
    log ok "decrypted mihomo config"
}

mihomo_encrypt() {
    need sops
    [ -f "$MIHOMO_DIR/age-key.txt" ] || die "age key not found: $MIHOMO_DIR/age-key.txt"
    [ -f "$MIHOMO_DIR/etc/mihomo/config.yaml" ] || die "plaintext config not found: $MIHOMO_DIR/etc/mihomo/config.yaml"
    [ -f "$MIHOMO_DIR/.sops.yaml" ] || die ".sops.yaml not found in $MIHOMO_DIR"

    local tmp
    tmp="$(mktemp)"
    if ! ( cd "$MIHOMO_DIR" && SOPS_AGE_KEY_FILE="$MIHOMO_DIR/age-key.txt" \
           sops --encrypt etc/mihomo/config.yaml ) > "$tmp"; then
        rm -f "$tmp"
        die "failed to encrypt mihomo config"
    fi
    mv "$tmp" "$MIHOMO_DIR/config.enc.yaml"
    log ok "encrypted mihomo config"
}

# --- software installation ----------------------------------------------------

pacman_install() {
    local label="$1"; shift
    log info "install $label"
    "${SUDO[@]}" pacman -S --noconfirm --needed "$@"
}

pacman_remove() {
    local label="$1"; shift
    log info "remove $label"
    "${SUDO[@]}" pacman -Rns --noconfirm "$@" || true
}

install_mihomo() {
    command -v curl >/dev/null 2>&1 || return 1

    local tag asset url tmp rc
    if ! tag="$(curl -fsS -o /dev/null -w '%{redirect_url}' \
        'https://github.com/MetaCubeX/mihomo/releases/latest' | sed 's#.*/##')"; then
        return 1
    fi
    [ "${tag#v}" != "$tag" ] || return 1

    case "$(uname -m)" in
        x86_64|amd64)  asset="mihomo-linux-amd64-v3-${tag}.pkg.tar.zst" ;;
        aarch64|arm64) asset="mihomo-linux-arm64-${tag}.pkg.tar.zst" ;;
        *) return 1 ;;
    esac

    url="https://github.com/MetaCubeX/mihomo/releases/download/${tag}/${asset}"
    tmp="$(mktemp -d)"
    log info "download $asset"
    if ! curl -fL --retry 3 -o "$tmp/$asset" "$url"; then
        rm -rf "$tmp"
        return 1
    fi

    if "${SUDO[@]}" pacman -U --noconfirm "$tmp/$asset"; then
        rc=0
    else
        rc=$?
    fi
    rm -rf "$tmp"
    return "$rc"
}

install_rime() {
    command -v git >/dev/null 2>&1 || return 1

    local rdir="$HOME/.local/share/fcitx5/rime"
    local plum="$HOME/.local/share/plum"

    if [ -d "$plum/.git" ]; then
        ( cd "$plum" && git pull --ff-only ) >/dev/null 2>&1 || true
    else
        mkdir -p "$(dirname "$plum")"
        git clone --depth 1 https://github.com/rime/plum.git "$plum" || return 1
    fi

    mkdir -p "$rdir"
    rime_dir="$rdir" bash "$plum/rime-install" iDvel/rime-ice || return 1
    rime_dir="$rdir" bash "$plum/rime-install" \
        "iDvel/rime-ice:others/recipes/config:schema=double_pinyin_flypy" || return 1
    rime_dir="$rdir" bash "$plum/rime-install" \
        "iDvel/rime-ice:others/recipes/grammar:schema=double_pinyin_flypy" || true
    rime_dir="$rdir" bash "$plum/rime-install" \
        "iDvel/rime-ice:others/recipes/reverse_tone:schema=double_pinyin_flypy" || true
}

cmd_software() {
    need pacman

    local base_tools=(which rsync bat)
    local shell_terminal=(fish alacritty)
    local sway_desktop=(swayidle swaylock fuzzel waybar swaync swayosd polkit-gnome grim slurp wl-clipboard playerctl)
    local portal=(xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr)
    local input_method=(fcitx5-im fcitx5-rime)
    local editor=(emacs-wayland)
    local dev_tools=(git base-devel gcc gdb cmake make man rustup)
    local fonts=(ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-iosevka-nerd)
    local system_monitor=(fastfetch btop rocm-smi-lib)
    local network=(openssh firefox firewalld)
    local greeter=(greetd greetd-tuigreet)
    local misc=(libnotify stow flatpak ripgrep sops age)

    log info "update system"
    "${SUDO[@]}" pacman -Syu --noconfirm

    pacman_install "basic tools"    "${base_tools[@]}"
    pacman_install "shell/terminal" "${shell_terminal[@]}"
    pacman_install "sway desktop"   "${sway_desktop[@]}"
    pacman_install "xdg portals"    "${portal[@]}"
    pacman_install "chinese input"  "${input_method[@]}"
    pacman_install "editor"         "${editor[@]}"
    pacman_install "dev tools"      "${dev_tools[@]}"
    pacman_install "fonts"          "${fonts[@]}"
    pacman_install "system monitor" "${system_monitor[@]}"
    pacman_install "network"        "${network[@]}"
    pacman_install "greeter"        "${greeter[@]}"
    pacman_install "misc"           "${misc[@]}"

    pacman_remove "old greeter" ly
    pacman_remove "old tools"   foot wmenu
    pacman_remove "old editors" vim nano

    log info "enable services"
    "${SUDO[@]}" systemctl enable --now sshd.service
    "${SUDO[@]}" systemctl enable greetd.service
    "${SUDO[@]}" systemctl enable --now firewalld.service

    log info "set default shell"
    if [ "$SHELL" != "/bin/fish" ] && [ "$SHELL" != "/usr/bin/fish" ]; then
        chsh -s /bin/fish
    fi

    log info "set up flatpak"
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    "${SUDO[@]}" flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub

    log info "set up rust"
    rustup toolchain add stable
    rustup component add rust-analyzer

    log info "set up git"
    git config --global user.name "shyweeds"
    git config --global user.email "2149934895@qq.com"
    git config --global gpg.format ssh
    git config --global user.signingKey ~/.ssh/id_ed25519
    git config --global commit.gpgSign true

    log info "generate ssh key"
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        log ok "ssh key exists"
    else
        ssh-keygen -t ed25519 -C "2149934895@qq.com" -f "$HOME/.ssh/id_ed25519" -N ""
    fi
    log info "public key"
    cat "$HOME/.ssh/id_ed25519.pub"

    log info "set up firewall"
    "${SUDO[@]}" firewall-cmd --zone=home --change-interface="$WIRED_IF" \
        || log warn "no wired interface $WIRED_IF"
    "${SUDO[@]}" firewall-cmd --zone=home --change-interface="$WIRELESS_IF" \
        || log warn "no wireless interface $WIRELESS_IF"
    "${SUDO[@]}" firewall-cmd --zone=home --set-target=REJECT --permanent
    "${SUDO[@]}" firewall-cmd --zone=home --remove-service=mdns
    "${SUDO[@]}" firewall-cmd --zone=home --remove-service=samba-client
    "${SUDO[@]}" firewall-cmd --zone=home --remove-service=ssh
    "${SUDO[@]}" firewall-cmd --zone=home \
        --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'
    "${SUDO[@]}" firewall-cmd --zone=trusted --change-interface="$VPN_IF" \
        || log warn "no interface $VPN_IF"
    "${SUDO[@]}" firewall-cmd --runtime-to-permanent
    "${SUDO[@]}" firewall-cmd --reload
    "${SUDO[@]}" firewall-cmd --zone=home --list-all
    "${SUDO[@]}" firewall-cmd --zone=trusted --list-all

    log info "set up snapper"
    pacman_install "snapper" snapper
    "${SUDO[@]}" systemctl enable --now snapper-timeline.timer
    "${SUDO[@]}" systemctl enable --now snapper-cleanup.timer
    [ -f /etc/snapper/configs/root ] || "${SUDO[@]}" snapper -c root create-config /
    if [ -f /etc/snapper/configs/home ]; then
        "${SUDO[@]}" snapper -c home delete-config
    fi

    log info "install mihomo"
    if install_mihomo; then
        log ok "mihomo installed"
    else
        log warn "mihomo install failed; run 'paru -S mihomo' then './deploy.sh config'"
    fi

    log info "install rime (ice-rime + flypy)"
    if install_rime; then
        log ok "rime installed to $HOME/.local/share/fcitx5/rime"
    else
        log warn "rime install failed; see README.org for the manual fallback"
    fi

    log ok "software done"
}

# --- config deployment --------------------------------------------------------

cmd_config() {
    need stow

    local mihomo_ok=0
    if command -v mihomo >/dev/null 2>&1; then
        mihomo_decrypt
        mihomo_ok=1
    else
        log warn "mihomo not installed; skipping its config (run './deploy.sh software' or 'paru -S mihomo')"
    fi

    log info "stow user configs"
    stow --dir="$ROOT" --target="$HOME" --restow \
        sway waybar systemd alacritty systemd_user_environment fuzzel swaync

    log info "stow system configs"
    "${SUDO[@]}" rm -rf /etc/greetd
    if [ "$mihomo_ok" -eq 1 ]; then
        "${SUDO[@]}" rm -rf /etc/mihomo
    fi
    local syspkgs=(greetd)
    [ "$mihomo_ok" -eq 1 ] && syspkgs+=(mihomo)
    "${SUDO[@]}" stow --dir="$ROOT" --target=/ --restow "${syspkgs[@]}"

    if [ "$mihomo_ok" -eq 1 ]; then
        if [ -f /usr/lib/systemd/system/mihomo.service ] || [ -f /etc/systemd/system/mihomo.service ]; then
            "${SUDO[@]}" systemctl daemon-reload
            "${SUDO[@]}" systemctl enable --now mihomo.service
        else
            log warn "no mihomo.service found; run: sudo mihomo -d /etc/mihomo"
        fi
    fi

    systemctl --user daemon-reload
    local svc
    for svc in "$ROOT"/systemd/.config/systemd/user/*.service; do
        [ -e "$svc" ] || continue
        systemctl --user enable "$(basename "$svc")"
    done

    log ok "config deployed"
}

# --- dispatch -----------------------------------------------------------------

case "${1:-config}" in
    config)   cmd_config ;;
    software) cmd_software ;;
    switch)
        [ $# -ge 2 ] || die "usage: ./deploy.sh switch <host>"
        [ -d "$ROOT/sway_$2" ] || die "unknown host: $2"
        [ -d "$ROOT/alacritty_$2" ] || die "unknown host: $2"
        ln -sfn "sway_$2" "$ROOT/sway"
        ln -sfn "alacritty_$2" "$ROOT/alacritty"
        log ok "switched to $2"
        ;;
    encrypt) mihomo_encrypt ;;
    decrypt) mihomo_decrypt ;;
    help|-h|--help) usage ;;
    *) usage >&2; exit 1 ;;
esac
