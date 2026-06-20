#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-ros2-mac-container:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-ros2_mac_container}"
CPUS="${CPUS:-4}"
MEMORY="${MEMORY:-8G}"
ROS2_SOCKET_BUFFER_BYTES="${ROS2_SOCKET_BUFFER_BYTES:-16777216}"

"${ROOT_DIR}/scripts/preflight.sh"

container run -d \
  --name "${CONTAINER_NAME}" \
  --cpus "${CPUS}" \
  --memory "${MEMORY}" \
  -e "ROS2_SOCKET_BUFFER_BYTES=${ROS2_SOCKET_BUFFER_BYTES}" \
  -p 127.0.0.1:3389:3389/tcp \
  -p 127.0.0.1:8765:8765/tcp \
  -p 127.0.0.1:7447:7447/tcp \
  "${IMAGE_NAME}"

echo "RDP: 127.0.0.1:3389"
echo "ROS bridge/WebSocket: 127.0.0.1:8765"
echo "Zenoh route: 127.0.0.1:7447"
echo "ROS 2 socket buffer cap: ${ROS2_SOCKET_BUFFER_BYTES} bytes"
