# ros2-mac-container

Apple Silicon ROS 2 desktop environment using Apple's `container` runtime, RDP desktop access, and wireless sensor-streaming patterns for camera, LiDAR, and telemetry payloads.

This repo targets macOS 26+ on Apple Silicon. It does not install Apple's `container` CLI for you; install it from the Apple project first, then run `container system start`.

## Quick Start

```bash
container system start
./scripts/build_container.sh
./scripts/start_container.sh
```

Connect from macOS with Microsoft Remote Desktop or another RDP client:

```text
Host: 127.0.0.1:3389
User: ros
Password: ros
```

Published ports:

```text
3389/tcp  KDE/xrdp desktop
8765/tcp  ROS bridge / WebSocket route
7447/tcp  Zenoh route
```

## Wireless Stream Simulator

The GitHub Pages demo lives at `docs/index.html`. It models sensor payloads, compression choices, wireless link capacity, estimated latency, packet loss, and saturation risk.

```bash
open docs/index.html
```

The public simulator URL is:

https://sandeep-devarapalli.github.io/ros2-mac-container/

## ROS Networking

The default container uses CycloneDDS:

```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///opt/ros2-mac-container/cyclonedds.xml
```

The entrypoint raises Linux socket buffer caps to support the default `8MB` CycloneDDS send and receive buffers:

```bash
ROS2_SOCKET_BUFFER_BYTES=16777216 ./scripts/start_container.sh
```

If socket tuning fails on a future runtime, lower `config/cyclonedds.xml` back to `4MB` before running ROS graph tools.

For physical robots or sensor rigs, prefer an edge device such as a Raspberry Pi or Jetson that publishes compressed topics over a dedicated 5 GHz or 6 GHz bridge. Keep raw USB sensors on the edge side and route ROS 2 data over the network.

Recommended transport direction:

- Cameras: `image_transport` with `compressed` or a hardware H.264 pipeline.
- LiDAR: point-cloud transport with compression where available, or Zenoh routing for lower discovery overhead.
- Telemetry: Micro-ROS or UDP-oriented bridges for low-bandwidth streams.

## Scripts

- `scripts/preflight.sh`: verifies macOS, Apple Silicon, and the `container` service.
- `scripts/build_container.sh`: builds `ros2-mac-container:latest`.
- `scripts/start_container.sh`: runs the container and publishes RDP/network ports.
- `scripts/attach_container.sh`: opens a shell as the `ros` user.
- `scripts/stop_container.sh`: stops the running container.

## Verification

Runtime verification status is tracked in `docs/runtime_verification.md`. On the current host, the official Apple `container` signed installer did not pass local signature validation, but the Apple `container` 1.0.0 source build works and has built and launched this ROS 2 image. RDP desktop access, RViz startup, GitHub Pages, and simulator selector checks have also been verified.

## References

- Apple `container`: https://github.com/apple/container
- ROS 2 ARM64 Mac reference: https://github.com/tatsuyai713/Development-Container-for-ROS2-on-Arm64-Mac
- Eclipse CycloneDDS: https://github.com/eclipse-cyclonedds/cyclonedds
- Eclipse Zenoh: https://github.com/eclipse-zenoh/zenoh
- ROS image transport: https://github.com/ros-perception/image_transport_plugins
