#!/usr/bin/env bash
set -euo pipefail

rm -f /run/xrdp/xrdp.pid /run/xrdp/xrdp-sesman.pid
mkdir -p /run/xrdp

/usr/sbin/xrdp-sesman --nodaemon &
/usr/sbin/xrdp --nodaemon &

cat <<'MSG'
ROS 2 desktop container is running.
RDP user: ros
RDP password: ros
Connect from macOS to 127.0.0.1:3389.
MSG

tail -f /dev/null

