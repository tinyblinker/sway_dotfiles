#!/usr/bin/env bash

# sway does not set DISPLAY/WAYLAND_DISPLAY in the systemd user environment
# See FS#63021
# Adapted from xorg's 50-systemd-user.sh, which achieves a similar goal.

# Upstream refuses to set XDG_CURRENT_DESKTOP so we have to.
systemctl --user set-environment XDG_CURRENT_DESKTOP=sway
systemctl --user import-environment DISPLAY \
                                    SWAYSOCK \
                                    WAYLAND_DISPLAY \
                                    XDG_CURRENT_DESKTOP
                                         
hash dbus-update-activation-environment 2>/dev/null && \
dbus-update-activation-environment --systemd DISPLAY \
                                             SWAYSOCK \
                                             XDG_CURRENT_DESKTOP=sway \
                                             WAYLAND_DISPLAY
systemctl --user start sway-session.target
