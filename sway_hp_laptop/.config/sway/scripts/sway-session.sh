#!/bin/sh
# blocking invocation until the sway exit
sway
# stop the sway-session and the dependencies will be ended by systemd-user automatically
systemctl --user stop sway-session.target

