#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ros2_mac_container}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
HOST="${ROSBRIDGE_HOST:-127.0.0.1}"
RDP_PORT="${RDP_PORT:-3389}"
ROSBRIDGE_PORT="${ROSBRIDGE_PORT:-8765}"
ZENOH_PORT="${ZENOH_PORT:-7447}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

check_port() {
  local port="$1"
  local label="$2"

  if nc -G 2 -z "${HOST}" "${port}" >/dev/null 2>&1; then
    echo "OK: ${label} reachable at ${HOST}:${port}"
  else
    echo "FAIL: ${label} is not reachable at ${HOST}:${port}" >&2
    exit 1
  fi
}

require_command container
require_command nc
require_command python3

if ! container list | awk -v name="${CONTAINER_NAME}" '$1 == name && $5 == "running" { found = 1 } END { exit found ? 0 : 1 }'; then
  echo "Container ${CONTAINER_NAME} is not running." >&2
  echo "Start it with: ./scripts/start_container.sh" >&2
  exit 1
fi

check_port "${RDP_PORT}" "RDP"
check_port "${ROSBRIDGE_PORT}" "ROS bridge WebSocket"
check_port "${ZENOH_PORT}" "Zenoh router"

"${ROOT_DIR}/scripts/check_rosbridge_websocket.py"

container exec --user ros "${CONTAINER_NAME}" bash -lc "source /opt/ros/${ROS_DISTRO}/setup.bash; ros2 doctor --report >/tmp/ros2-doctor-runtime-networking.log"
echo "OK: ros2 doctor completed inside ${CONTAINER_NAME}"

container exec "${CONTAINER_NAME}" bash -lc "ps -eo args | grep 'rosbridge_websocket' | grep -v grep >/dev/null"
echo "OK: rosbridge process is running"

container exec "${CONTAINER_NAME}" bash -lc "ps -eo args | grep 'rmw_zenohd' | grep -v grep >/dev/null"
echo "OK: Zenoh process is running"

container exec "${CONTAINER_NAME}" bash -lc "grep -q 'Rosbridge WebSocket server started on port' /tmp/rosbridge-websocket.log"
echo "OK: rosbridge startup log found"

container exec "${CONTAINER_NAME}" bash -lc "grep -q 'Zenoh can be reached at:' /tmp/zenoh-router.log"
echo "OK: Zenoh startup log found"

echo "Runtime networking smoke passed for ${CONTAINER_NAME}."
