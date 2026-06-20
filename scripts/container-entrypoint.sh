#!/usr/bin/env bash
set -euo pipefail

ROS2_SOCKET_BUFFER_BYTES="${ROS2_SOCKET_BUFFER_BYTES:-16777216}"

if [[ "${ROS2_SOCKET_BUFFER_BYTES}" =~ ^[0-9]+$ ]] && [[ "${ROS2_SOCKET_BUFFER_BYTES}" -gt 0 ]]; then
  if sysctl -w "net.core.rmem_max=${ROS2_SOCKET_BUFFER_BYTES}" >/dev/null \
    && sysctl -w "net.core.wmem_max=${ROS2_SOCKET_BUFFER_BYTES}" >/dev/null; then
    echo "ROS 2 socket buffer caps set to ${ROS2_SOCKET_BUFFER_BYTES} bytes."
  else
    echo "Warning: failed to raise ROS 2 socket buffer caps; use a 4MB CycloneDDS profile if DDS startup fails." >&2
  fi
else
  echo "Skipping ROS 2 socket buffer tuning; ROS2_SOCKET_BUFFER_BYTES=${ROS2_SOCKET_BUFFER_BYTES}" >&2
fi

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
