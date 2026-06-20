# ros2-mac-container

Apple Silicon ROS 2 desktop environment using Apple's `container` runtime, RDP desktop access, and wireless sensor-streaming patterns for camera, LiDAR, and telemetry payloads.

The goal is a native-feeling Ubuntu ROS 2 desktop on an ARM64 Mac, with KDE/xrdp for RViz and rqt, plus host-published ports for rosbridge and Zenoh so robot or sensor data can stream in over Wi-Fi instead of USB passthrough.

## What You Get

- Ubuntu 24.04 ARM64 with ROS 2 Jazzy desktop.
- KDE Plasma over xrdp at `127.0.0.1:3389`.
- CycloneDDS configured for Wi-Fi-oriented ROS graph use.
- `rosbridge_server` at `127.0.0.1:8765`.
- Zenoh router from `rmw_zenoh_cpp` at `127.0.0.1:7447`.
- A GitHub Pages wireless stream simulator for payload/compression/link tradeoffs.
- Edge-device setup docs for Raspberry Pi, Jetson, or robot-side computers.
- Simulation and navigation testing notes for turtlesim, the verified minimal TurtleBot/Gazebo bridge, and optional full Nav2 bringup.

## Requirements

- macOS 26+ on Apple Silicon.
- Apple's `container` CLI and service.
- An RDP client such as Microsoft Remote Desktop or FreeRDP.
- About 8 GB RAM available for the container.

This repo does not install Apple's `container` CLI for you. Install it from the Apple project, then start the runtime:

```bash
container system start
```

If the signed installer does not validate on your Mac, do not bypass signature validation casually. See `docs/runtime_verification.md` for the source-build path used during this repo's verification.

## Quick Start

```bash
git clone https://github.com/sandeep-devarapalli/ros2-mac-container.git
cd ros2-mac-container
container system start
./scripts/build_container.sh
./scripts/start_container.sh
./scripts/check_runtime_networking.sh
```

Then connect from macOS with Microsoft Remote Desktop or another RDP client:

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

The default container user is `ros`, password `ros`.

## Wireless Stream Simulator

The GitHub Pages demo lives at `docs/index.html`. It models sensor payloads, compression choices, wireless link capacity, estimated latency, packet loss, and saturation risk.

```bash
open docs/index.html
```

The public simulator URL is:

https://sandeep-devarapalli.github.io/ros2-mac-container/

## Runtime Verification

After `./scripts/start_container.sh`, run:

```bash
./scripts/check_runtime_networking.sh
```

This verifies:

- Apple `container` can see `ros2_mac_container` running.
- RDP, rosbridge, and Zenoh ports are reachable from macOS.
- rosbridge can publish and receive a `std_msgs/String` over WebSocket.
- `ros2 doctor --report` completes inside the container.
- rosbridge and Zenoh processes/logs are present.

Runtime verification status and current host notes are tracked in `docs/runtime_verification.md`.

## Test The ROS 2 Environment

Start with the repeatable runtime smoke:

```bash
./scripts/check_runtime_networking.sh
```

Then RDP into the container and test the included lightweight simulator:

```bash
source /opt/ros/jazzy/setup.bash
ros2 run turtlesim turtlesim_node
```

For navigation work, install simulator packages only after the base runtime is healthy. The minimal TurtleBot/Gazebo bridge has been verified in the live container; full Nav2 bringup should be proven next before adding it to the base image. The optional path is documented in `docs/simulation_navigation.md`.

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

The entrypoint also starts:

- `rosbridge_server` on `127.0.0.1:8765`
- `rmw_zenohd` on `127.0.0.1:7447`, using `config/zenoh-router.json5`

You can run just the rosbridge WebSocket smoke from the macOS host:

```bash
scripts/check_rosbridge_websocket.py
```

For physical robots or sensor rigs, prefer an edge device such as a Raspberry Pi or Jetson that publishes compressed topics over a dedicated 5 GHz or 6 GHz bridge. Keep raw USB sensors on the edge side and route ROS 2 data over the network.

Recommended transport direction:

- Cameras: `image_transport` with `compressed` or a hardware H.264 pipeline.
- LiDAR: point-cloud transport with compression where available, or Zenoh routing for lower discovery overhead.
- Telemetry: Micro-ROS or UDP-oriented bridges for low-bandwidth streams.

## Scripts

- `scripts/preflight.sh`: verifies macOS, Apple Silicon, and the `container` service.
- `scripts/build_container.sh`: builds `ros2-mac-container:latest`.
- `scripts/start_container.sh`: runs the container and publishes RDP/network ports.
- `scripts/check_runtime_networking.sh`: verifies the running container, published ports, rosbridge, Zenoh, and ROS doctor.
- `scripts/check_rosbridge_websocket.py`: publishes and receives a ROS `std_msgs/String` through rosbridge.
- `scripts/attach_container.sh`: opens a shell as the `ros` user.
- `scripts/stop_container.sh`: stops the running container.

## Typical Workflow

On the Mac:

```bash
./scripts/start_container.sh
./scripts/check_runtime_networking.sh
./scripts/attach_container.sh
```

Inside the container shell:

```bash
source /opt/ros/jazzy/setup.bash
rviz2
```

On the robot or sensor edge device, publish compressed camera, point-cloud, and telemetry topics over a dedicated 5 GHz or 6 GHz link. Keep high-bandwidth USB devices attached to the edge device, not the Mac container.

See `docs/edge_device_setup.md` for CycloneDDS peer mode, Zenoh route checks, compressed camera transport, point-cloud guidance, and edge-to-Mac smoke tests.

## Documentation

- `docs/architecture.md`: system layout and responsibility split.
- `docs/rdp_setup.md`: RDP client setup and troubleshooting.
- `docs/wireless_streaming.md`: transport guidance for Wi-Fi sensor streams.
- `docs/edge_device_setup.md`: robot or sensor edge-device setup.
- `docs/simulation_navigation.md`: ROS smoke tests, turtlesim, and optional Nav2/TurtleBot3 simulation.
- `docs/runtime_verification.md`: current host verification notes and evidence.

## References

- Apple `container`: https://github.com/apple/container
- ROS 2 ARM64 Mac reference: https://github.com/tatsuyai713/Development-Container-for-ROS2-on-Arm64-Mac
- Eclipse CycloneDDS: https://github.com/eclipse-cyclonedds/cyclonedds
- Eclipse Zenoh: https://github.com/eclipse-zenoh/zenoh
- ROS image transport: https://github.com/ros-perception/image_transport_plugins
