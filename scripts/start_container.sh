#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-ros2-mac-container:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-ros2_mac_container}"
CPUS="${CPUS:-4}"
MEMORY="${MEMORY:-8G}"
ROS2_SOCKET_BUFFER_BYTES="${ROS2_SOCKET_BUFFER_BYTES:-16777216}"
ROSBRIDGE_PORT="${ROSBRIDGE_PORT:-8765}"
START_ROSBRIDGE="${START_ROSBRIDGE:-1}"
START_ZENOH_ROUTER="${START_ZENOH_ROUTER:-1}"
ZENOH_ROUTER_CONFIG_URI="${ZENOH_ROUTER_CONFIG_URI:-/opt/ros2-mac-container/zenoh-router.json5}"

"${ROOT_DIR}/scripts/preflight.sh"

container run -d \
  --name "${CONTAINER_NAME}" \
  --cpus "${CPUS}" \
  --memory "${MEMORY}" \
  -e "ROS2_SOCKET_BUFFER_BYTES=${ROS2_SOCKET_BUFFER_BYTES}" \
  -e "ROSBRIDGE_PORT=${ROSBRIDGE_PORT}" \
  -e "START_ROSBRIDGE=${START_ROSBRIDGE}" \
  -e "START_ZENOH_ROUTER=${START_ZENOH_ROUTER}" \
  -e "ZENOH_ROUTER_CONFIG_URI=${ZENOH_ROUTER_CONFIG_URI}" \
  -p 127.0.0.1:3389:3389/tcp \
  -p 127.0.0.1:8765:"${ROSBRIDGE_PORT}"/tcp \
  -p 127.0.0.1:7447:7447/tcp \
  "${IMAGE_NAME}"

echo "RDP: 127.0.0.1:3389"
echo "ROS bridge/WebSocket: 127.0.0.1:8765"
echo "Zenoh route: 127.0.0.1:7447"
echo "ROS 2 socket buffer cap: ${ROS2_SOCKET_BUFFER_BYTES} bytes"
echo "ROS bridge enabled: ${START_ROSBRIDGE}"
echo "Zenoh router enabled: ${START_ZENOH_ROUTER}"
