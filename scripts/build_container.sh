#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-ros2-mac-container:latest}"

"${ROOT_DIR}/scripts/preflight.sh"
container build -t "${IMAGE_NAME}" "${ROOT_DIR}"

