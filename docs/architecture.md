# Architecture

This repo pairs Apple's native `container` runtime with an ARM64 Ubuntu ROS 2 desktop image. The container runs graphical ROS tools while physical sensors stay attached to an edge robot computer and stream data over Wi-Fi.

```text
Camera / LiDAR / IMU
        |
        v
Edge robot computer
        |
        | Dedicated 5 GHz / 6 GHz bridge
        v
Apple Silicon Mac host
        |
        v
Apple container VM
        |
        v
ROS 2 desktop tools, RViz2, rqt, rosbridge
```

## Layers

- Host: macOS 26+ on Apple Silicon, Apple `container`, and an RDP client.
- Container: Ubuntu 24.04 ARM64, ROS 2 Jazzy, KDE/xrdp, CycloneDDS.
- Edge robot: Raspberry Pi, Jetson, or another sensor-side computer.

