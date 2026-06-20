#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ros2_mac_container}"

if ! command -v container >/dev/null 2>&1; then
  echo "Apple container CLI is not installed or not on PATH."
  exit 1
fi

container stop "${CONTAINER_NAME}"

