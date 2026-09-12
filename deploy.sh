#!/usr/bin/env bash
set -euo pipefail

# stow 目录（脚本所在目录）
STOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 部署到 $HOME 的包
HOME_PACKAGES=(sway waybar systemd alacritty systemd_user_environment)

# 部署到系统根 / 的包
SYSTEM_PACKAGES=(greetd)

# 检查依赖
if ! command -v stow >/dev/null 2>&1; then
    echo "错误：未安装 GNU stow" >&2
    exit 1
fi

# 部署用户级配置到 $HOME
stow --dir="$STOW_DIR" --target="$HOME" --restow "${HOME_PACKAGES[@]}"

# 部署系统级配置到 /（/etc/greetd，需要 root）
if [ "$(id -u)" -eq 0 ]; then
    stow --dir="$STOW_DIR" --target="/" --restow "${SYSTEM_PACKAGES[@]}"
else
    sudo stow --dir="$STOW_DIR" --target="/" --restow "${SYSTEM_PACKAGES[@]}"
fi

# 重新加载并启用已注册的 systemd 用户服务（即包内的 .service 文件）
systemctl --user daemon-reload
for svc in "$STOW_DIR"/systemd/.config/systemd/user/*.service; do
    [ -e "$svc" ] || continue
    systemctl --user enable "$(basename "$svc")"
done

echo "部署完成"
