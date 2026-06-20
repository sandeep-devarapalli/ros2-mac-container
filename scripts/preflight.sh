#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This workflow targets macOS hosts."
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "This workflow targets Apple Silicon arm64 hosts."
  exit 1
fi

if ! command -v container >/dev/null 2>&1; then
  echo "Apple container CLI is not installed or not on PATH."
  echo "Install it from https://github.com/apple/container/releases, then run: container system start"
  exit 1
fi

container system start >/dev/null 2>&1 || {
  echo "Apple container system service could not be started. Try manually: container system start"
  exit 1
}

echo "Preflight passed."

