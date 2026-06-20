# Edge Device Setup

Use this when physical sensors stay on a Raspberry Pi, Jetson, or robot computer and the Mac container is the ROS 2 desktop, RViz, and analysis workstation.

## Topology

```text
Camera / LiDAR / IMU
        |
        v
Edge device running ROS 2
        |
        | Dedicated 5 GHz / 6 GHz link
        v
Mac host
        |
        v
Apple container: ROS 2 desktop, RViz, rosbridge, Zenoh
```

Keep raw USB devices attached to the edge device. Stream ROS topics over the network.

## Assumptions

- The edge device runs Ubuntu 24.04 ARM64 or another ROS 2 Jazzy-capable OS.
- The Mac container is already running with `./scripts/start_container.sh`.
- `./scripts/check_runtime_networking.sh` passes on the Mac.
- Edge and Mac are on the same trusted network or a dedicated robot Wi-Fi bridge.

## CycloneDDS Peer Mode

On the Mac/container side, add the edge device IP to `config/cyclonedds.xml` before rebuilding:

```xml
<Peer Address="192.168.1.20"/>
```

On the edge device, copy `config/edge-cyclonedds.xml`, replace `MAC_OR_CONTAINER_IP`, then run:

```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file://$PWD/edge-cyclonedds.xml
```

Use peer mode on noisy Wi-Fi because ROS 2 multicast discovery is often unreliable across consumer access points.

## Camera Topics

Avoid raw image topics over Wi-Fi when possible. Prefer compressed transport on the edge device:

```bash
ros2 run image_transport republish raw compressed \
  --ros-args \
  -r in:=/camera/image_raw \
  -r out/compressed:=/camera/image_compressed
```

For higher-rate RGB-D cameras, prefer a hardware H.264/H.265 pipeline on the edge device and keep raw recording local.

## Point Clouds

Raw 3D point clouds can saturate Wi-Fi quickly. Keep full-rate raw topics local to the edge device for recording and safety loops, then publish a reduced or compressed stream for the Mac:

```bash
ros2 topic hz /points
ros2 topic bw /points
```

If your point-cloud transport plugin is available, publish the compressed transport topic. Otherwise downsample on the edge device before forwarding to the Mac.

## Zenoh Route

The Mac container starts `rmw_zenohd` on port `7447`. From the edge device, verify the route:

```bash
nc -vz MAC_HOST_IP 7447
```

For ROS graphs that use Zenoh RMW, install the matching Jazzy package on the edge device:

```bash
sudo apt-get update
sudo apt-get install ros-jazzy-rmw-zenoh-cpp
```

Then run ROS nodes with:

```bash
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
```

Keep CycloneDDS as the default until the Zenoh path has been tested with your robot topics.

## Rosbridge Smoke

From any machine that can reach the Mac host, verify rosbridge:

```bash
ROSBRIDGE_HOST=MAC_HOST_IP ROSBRIDGE_PORT=8765 scripts/check_rosbridge_websocket.py
```

If the script is not available on the edge device, test from the Mac first:

```bash
./scripts/check_rosbridge_websocket.py
```

## Bringup Checklist

1. Start the Mac container.
2. Run `./scripts/check_runtime_networking.sh` on the Mac.
3. Confirm edge-to-Mac reachability on `7447` and any required ROS 2 peer addresses.
4. Start low-bandwidth telemetry first.
5. Add compressed camera or downsampled point cloud streams.
6. Open RViz through RDP and inspect topic rate, bandwidth, TF, and latency.

