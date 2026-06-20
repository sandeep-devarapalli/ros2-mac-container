#!/usr/bin/env bash
set -euo pipefail

ROS2_SOCKET_BUFFER_BYTES="${ROS2_SOCKET_BUFFER_BYTES:-16777216}"
ROSBRIDGE_PORT="${ROSBRIDGE_PORT:-8765}"
START_ROSBRIDGE="${START_ROSBRIDGE:-1}"
START_ZENOH_ROUTER="${START_ZENOH_ROUTER:-1}"
ZENOH_ROUTER_CONFIG_URI="${ZENOH_ROUTER_CONFIG_URI:-/opt/ros2-mac-container/zenoh-router.json5}"

if ! [[ "${ROSBRIDGE_PORT}" =~ ^[0-9]+$ ]]; then
  echo "Invalid ROSBRIDGE_PORT=${ROSBRIDGE_PORT}" >&2
  exit 2
fi

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

if [[ "${START_ROSBRIDGE}" == "1" ]]; then
  ROSBRIDGE_PORT="${ROSBRIDGE_PORT}" runuser -u ros -- bash -lc "source /opt/ros/${ROS_DISTRO}/setup.bash; exec ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=\${ROSBRIDGE_PORT}" \
    >/tmp/rosbridge-websocket.log 2>&1 &
  echo "ROS bridge WebSocket starting on port ${ROSBRIDGE_PORT}."
fi

if [[ "${START_ZENOH_ROUTER}" == "1" ]]; then
  ZENOH_ROUTER_CONFIG_URI="${ZENOH_ROUTER_CONFIG_URI}" runuser -u ros -- bash -lc "source /opt/ros/${ROS_DISTRO}/setup.bash; export ZENOH_ROUTER_CONFIG_URI; exec /opt/ros/${ROS_DISTRO}/lib/rmw_zenoh_cpp/rmw_zenohd" \
    >/tmp/zenoh-router.log 2>&1 &
  echo "Zenoh router starting with ${ZENOH_ROUTER_CONFIG_URI}."
fi

cat <<'MSG'
ROS 2 desktop container is running.
RDP user: ros
RDP password: ros
Connect from macOS to 127.0.0.1:3389.
MSG

tail -f /dev/null
