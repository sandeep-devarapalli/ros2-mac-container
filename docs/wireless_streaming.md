# Wireless Streaming

macOS container environments are not a reliable place to pass high-bandwidth USB sensors directly into Linux. Use an edge device on the robot and stream ROS 2 data into the Mac container.

## Recommended Layout

```text
Robot sensors -> Edge computer -> Wi-Fi bridge -> Mac host -> Apple container -> ROS 2 tools
```

Use a dedicated 5 GHz or 6 GHz bridge when possible.

For the full robot-side setup, see `docs/edge_device_setup.md`.

## Cameras

Avoid raw image topics across Wi-Fi. Prefer:

```bash
ros2 run image_transport republish raw compressed
```

For higher efficiency, use a hardware H.264 encoder on the edge device and decode inside the container or host-side viewer.

## LiDAR

Raw point clouds can burst and fragment heavily over Wi-Fi. Prefer compressed point-cloud transport where available, and keep full-rate raw topics local to the edge computer for recording or safety-critical logic.

## DDS and Zenoh

Default ROS 2 discovery can be noisy on Wi-Fi. Two practical options:

- Use CycloneDDS with explicit peers in `config/cyclonedds.xml`.
- Run Zenoh on the edge device and in the container, using port `7447`.

The container starts `rmw_zenohd` with `config/zenoh-router.json5`, which listens on `tcp/0.0.0.0:7447`. The host publishes this as `127.0.0.1:7447`.

## Host Smoke Checks

After `scripts/start_container.sh`, verify both network ports from macOS:

```bash
scripts/check_runtime_networking.sh
```

For lower-level port-only checks:

```bash
nc -vz 127.0.0.1 8765
nc -vz 127.0.0.1 7447
scripts/check_rosbridge_websocket.py
```

The rosbridge smoke publishes `std_msgs/String` to `/codex_rosbridge_smoke` through WebSocket and waits for the echoed subscription message.
