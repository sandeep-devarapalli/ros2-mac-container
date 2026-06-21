# Robotics Sensor, Chip, and Navigation Integration Research

This note is separate from the converted Raspberry Pi sensor DOCX. It records the practical architecture choices for a Raspberry Pi 5, optional Jetson/accelerator edge computer, MCU, flight controller, and the Mac-hosted ROS 2 Jazzy container.

## Source posture

Prefer upstream and official documentation before adopting blog recipes:

- ROS 2 Jazzy targets Ubuntu 24.04 Noble on `amd64` and `arm64`, with deb packages available for Noble and `rmw_fastrtps_cpp` as the default RMW; `rmw_cyclonedds_cpp` is also Tier 1. Sources: [ROS 2 Jazzy release notes](https://raw.githubusercontent.com/ros2/ros2_documentation/jazzy/source/Releases/Release-Jazzy-Jalisco.rst), [ROS 2 Ubuntu deb install docs](https://raw.githubusercontent.com/ros2/ros2_documentation/jazzy/source/Installation/Ubuntu-Install-Debs.rst), and [REP 2000](https://raw.githubusercontent.com/ros-infrastructure/rep/master/rep-2000.rst).
- Ubuntu documents Raspberry Pi installation with Raspberry Pi Imager and lists Raspberry Pi 5 as supported/certified for current Ubuntu/Core images. Source: [Ubuntu Raspberry Pi download page](https://ubuntu.com/download/raspberry-pi).
- Raspberry Pi documents the Pi 5 hardware, GPIO/header functions, hardware communication, camera stack, `rpicam-apps`, and Picamera2. Sources: [Raspberry Pi computer documentation](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html) and [Raspberry Pi camera software](https://www.raspberrypi.com/documentation/computers/camera_software.html).
- Depth-camera integration should start from the upstream RealSense ROS 2 wrapper and SDK, not ad hoc topic shims. Sources: [realsense-ros](https://github.com/realsenseai/realsense-ros) and [librealsense](https://github.com/realsenseai/librealsense).
- Navigation should start from Nav2's setup and tutorial path, with `robot_localization` for state estimation and SLAM as a separate mapping/localization layer. Sources: [Nav2 documentation](https://docs.nav2.org/), [Nav2 first-time robot setup](https://docs.nav2.org/setup_guides/index.html), and [robot_localization](https://github.com/cra-ros-pkg/robot_localization).
- PX4 and ArduPilot companion integration should follow the autopilot projects' companion-computer docs. Sources: [PX4 companion computer guide](https://docs.px4.io/main/en/companion_computer/pixhawk_companion), [PX4 ROS 2 guide](https://docs.px4.io/main/en/ros2/user_guide), and [ArduPilot companion computers](https://ardupilot.org/dev/docs/companion-computers.html).
- Microcontroller integration should use micro-ROS when the MCU needs first-class ROS entities, and MAVLink or uXRCE-DDS when the endpoint is an autopilot. Sources: [micro-ROS architecture](https://micro.ros.org/docs/overview/features/), [micro-ROS first Linux application](https://micro.ros.org/docs/tutorials/core/first_application_linux/), [PX4 ROS 2 guide](https://docs.px4.io/main/en/ros2/user_guide), and [MAVLink developer guide](https://mavlink.io/en/).
- Edge-to-Mac transport choices should be explicit: DDS/CycloneDDS for normal ROS 2 graphs, Zenoh bridge/router for constrained or routed networks, and rosbridge for web/tooling access. Sources: [Cyclone DDS](https://github.com/eclipse-cyclonedds/cyclonedds), [rmw_cyclonedds](https://github.com/ros2/rmw_cyclonedds), [zenoh-plugin-ros2dds](https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds), and [rosbridge_suite](https://github.com/RobotWebTools/rosbridge_suite).
- Jetson should be treated as an optional perception accelerator, not the default sensor hub. Sources: [NVIDIA JetPack](https://developer.nvidia.com/embedded/jetpack), [JetPack downloads and notes](https://developer.nvidia.com/embedded/jetson-linux), and [NVIDIA Isaac ROS compute setup](https://nvidia-isaac-ros.github.io/getting_started/hardware_setup/compute/index.html).

## Architecture decisions

### Raspberry Pi 5 role

Use the Raspberry Pi 5 as the default robot-side sensor hub when the workload is acquisition, timestamping, light filtering, and ROS 2 publication:

- Run Ubuntu 24.04 ARM64 plus ROS 2 Jazzy when the Pi needs to join the same ROS 2 graph as the Mac container.
- Keep USB sensors physically attached to the Pi: 2D LiDAR, RealSense/depth camera, USB cameras, serial GNSS, and USB-to-UART adapters.
- Keep Pi CSI cameras on the Pi camera stack. Use `rpicam-apps`/Picamera2 for capture, then publish `sensor_msgs/Image` plus `CameraInfo` through ROS 2.
- Use GPIO only for low-rate, electrical-interface work: triggers, simple digital IO, I2C/SPI environmental sensors, or UART devices. Do not put high-rate perception traffic through GPIO.
- Publish compressed or filtered streams over Wi-Fi/Ethernet instead of trying to pass raw USB devices into the Mac container.

Recommended Pi topics:

```text
/camera/front/image_raw or /camera/front/image_rect
/camera/front/camera_info
/camera/front/image_raw/compressed
/depth/color/image_raw
/depth/depth/image_rect_raw
/depth/points
/scan
/imu/data
/fix
/diagnostics
```

### Jetson or neural accelerator role

Add a Jetson only when the robot needs local neural perception that is too heavy for the Pi:

- Run object detection, segmentation, visual odometry, depth post-processing, or Isaac ROS acceleration on the Jetson.
- Keep the Pi as the deterministic sensor and low-level IO hub if it already owns the camera/LiDAR wiring.
- Publish semantic outputs as proposals: masks, detections, tracks, depth proposals, and compressed feature/topic streams. Keep metric state estimation and safety validation separate.
- Use JetPack/Jetson Linux versions that match the deployed hardware. JetPack provides CUDA, cuDNN, TensorRT, multimedia APIs, VPI/OpenCV, DeepStream, Holoscan, and Isaac ROS support.

Recommended Jetson topics:

```text
/perception/detections
/perception/segments
/perception/tracks
/depth/points/filtered
/visual_odometry
/diagnostics
```

### MCU role

Use a microcontroller for timing-sensitive IO and small embedded control loops:

- Motor encoders, PWM, hard real-time sampling, emergency stop chains, contact switches, and simple range/temperature sensors belong on an MCU when Linux jitter is unacceptable.
- Use micro-ROS if the MCU should appear as ROS 2 publishers/subscribers/services through a micro-ROS agent.
- Use a simple serial protocol when the interface is private to the Pi and does not need to join the ROS graph directly.
- Use MAVLink only when the MCU is effectively part of a vehicle/autopilot ecosystem.

Recommended MCU topics through micro-ROS:

```text
/wheel/encoder_left
/wheel/encoder_right
/joint_states
/battery_state
/estop
/range/*
```

### Flight controller role

Keep flight-critical control on PX4 or ArduPilot:

- The flight controller owns arming, stabilization, failsafes, RC/manual override, actuator mixing, IMU/barometer fusion, and flight-mode safety.
- The companion computer sends high-level setpoints, missions, perception summaries, or navigation aids only after bench validation.
- PX4 expects companion links over `TELEM2` by default for MAVLink; PX4 can use ROS 2/uXRCE-DDS by disabling MAVLink on the port and enabling the uXRCE-DDS client.
- ArduPilot companion setups should follow ArduPilot's companion computer guidance, usually via MAVLink.

Recommended autopilot links:

```text
PX4/ArduPilot <-> Pi or Jetson: UART/USB/Ethernet MAVLink
PX4 <-> ROS 2 companion: uXRCE-DDS where a ROS 2-native PX4 bridge is required
Companion <-> Mac container: DDS/CycloneDDS, Zenoh, or rosbridge depending on network need
```

### Mac ROS 2 container role

Use the Mac container as the development, visualization, simulation, and operator workstation:

- Run RViz, rqt, rosbag inspection, Nav2 experiments, SLAM evaluation, and the wireless stream simulator.
- Keep raw sensor attachment on the edge device. The Mac container should consume ROS topics over the network.
- Use RDP at `127.0.0.1:3389` for GUI verification, rosbridge at `127.0.0.1:8765` for WebSocket tools, and Zenoh at `127.0.0.1:7447` for routed edge networking.
- Treat the Mac container as a validation and supervisory environment, not as the first place to host robot-critical control loops.

## Sensor attachment map

| Sensor or device | Attach to | Transport into ROS | Primary ROS topics |
| --- | --- | --- | --- |
| Pi CSI camera | Raspberry Pi 5 | Picamera2/rpicam plus ROS image publisher | `/camera/*/image_*`, `/camera/*/camera_info` |
| USB camera | Pi for simple rigs, Jetson for neural perception | V4L2/ROS camera driver, image_transport | `/camera/*/image_raw`, `/camera/*/image_raw/compressed` |
| RealSense/depth camera | Pi for light use, Jetson for heavier point-cloud/perception work | `realsense-ros` | `/depth/*`, `/camera/*`, `/points` |
| 2D LiDAR | Pi USB/UART | Vendor ROS 2 driver publishing `sensor_msgs/LaserScan` | `/scan` |
| IMU | Flight controller if flight-critical; Pi/MCU otherwise | Autopilot MAVLink/uXRCE-DDS, ROS driver, or micro-ROS | `/imu/data` |
| GPS/GNSS | Flight controller for aircraft; Pi USB/UART for ground robots | MAVLink/uXRCE-DDS, NMEA/UBX driver | `/fix`, `/navsat`, `/gps/*` |
| Encoders/contact sensors | MCU | micro-ROS agent or Pi serial bridge | `/joint_states`, `/wheel/*`, `/estop` |
| Environmental I2C/SPI sensors | Pi or MCU | Linux I2C/SPI driver, Python/C++ ROS node, or micro-ROS | `/temperature`, `/pressure`, `/humidity`, `/range/*` |

## Transport decisions

### CycloneDDS

Use CycloneDDS for the normal ROS 2 edge-to-container graph when multicast/discovery works or can be configured. It is a Tier 1 ROS 2 Jazzy middleware implementation and fits direct Pi-to-Mac ROS 2 topic exchange.

Use it first for:

- Pi publishing `/scan`, `/imu/data`, `/fix`, and compressed camera topics to the Mac container.
- Mac RViz/Nav2 consuming robot topics on the same network.
- Development networks where `ROS_DOMAIN_ID`, interface allowlists, and CycloneDDS XML can be controlled.

### Zenoh

Use Zenoh when DDS discovery or multi-robot routing gets brittle across Wi-Fi, routed subnets, or remote links. The Zenoh ROS 2/DDS bridge discovers local ROS 2 nodes on a domain ID, then routes topics/services/actions over Zenoh. Current bridge defaults use router mode and listen on TCP `7447`, matching this repo's exposed Zenoh port.

Use it for:

- One bridge on each robot and one bridge on the Mac container.
- Multi-robot namespace isolation.
- Networks where static endpoint configuration is more reliable than DDS multicast.

### rosbridge

Use rosbridge for browser dashboards, non-ROS tools, and lightweight command/status panels. Do not make rosbridge the main high-bandwidth camera or point-cloud transport.

Use it for:

- Web status panels.
- Simple telemetry or operator controls.
- Integration tests from macOS to the container WebSocket.

## Navigation stack decisions

- Start with state-estimation hygiene before Nav2: stable frames, timestamps, `base_link`, `odom`, `map`, sensor frames, and covariances.
- Use `robot_localization` to fuse wheel odometry, IMU, and GNSS where available. Keep raw sensor topics visible for debugging.
- Use 2D LiDAR `/scan` as the first Nav2 obstacle source because it is simpler to validate than camera-only navigation.
- Add SLAM only after `/scan`, odometry, TF, and time sync are stable. Treat maps as outputs of a validated sensor/pose pipeline, not as proof that the sensor integration is correct.
- Use camera/depth/semantic perception as additional layers after the 2D navigation path is healthy.

## Test order

### 1. Bench bringup on the Raspberry Pi

1. Flash Ubuntu 24.04 ARM64 with Raspberry Pi Imager and enable SSH.
2. Install ROS 2 Jazzy packages and run the talker/listener demo locally.
3. Confirm hardware devices:
   - `ls /dev/video*` for USB cameras and RealSense color/depth endpoints.
   - `libcamera-hello` or `rpicam-hello` for CSI camera sanity.
   - `i2cdetect`, `gpioinfo`, or driver-specific tools for I2C/GPIO.
   - `ls /dev/serial/by-id/*` for LiDAR, GNSS, MCU, and autopilot serial devices.
4. Publish one topic at a time and measure it:
   - `ros2 topic hz /scan`
   - `ros2 topic hz /camera/front/image_raw/compressed`
   - `ros2 topic echo /imu/data --once`
   - `ros2 topic echo /fix --once`

### 2. Edge-to-Mac transport

1. Start the Mac container with `./scripts/start_container.sh`.
2. Run `./scripts/check_runtime_networking.sh` before claiming RDP, rosbridge, Zenoh, or ROS graph health.
3. Verify `ROS_DOMAIN_ID` and RMW settings on the Pi and Mac container.
4. First try CycloneDDS direct ROS 2 discovery for low-rate topics.
5. Add compressed image topics, then check bandwidth and latency.
6. If discovery or routed networking fails, run Zenoh bridge/router on the Pi and Mac container and keep the endpoint config checked in.
7. Use rosbridge only for WebSocket smoke and browser UI integration.

### 3. Navigation minimum viable proof

1. In the Mac container, visualize `/scan`, `/tf`, `/odom`, `/imu/data`, and `/fix` in RViz.
2. Confirm TF tree is stable and timestamps are current.
3. Record a short bag from the edge topics.
4. Run SLAM or localization against the bag before running the live robot.
5. Run Nav2 with a conservative footprint, low speeds, and manual e-stop available.
6. Add depth camera, semantic masks, Jetson perception, or flight-controller setpoints only after the 2D `/scan` path is boringly repeatable.

### 4. Autopilot proof

1. Validate the flight controller with vendor ground-control tooling before connecting ROS.
2. Confirm companion link electrically and logically: correct UART voltage, baud, port, and heartbeat.
3. For MAVLink, verify heartbeat and telemetry before sending any setpoint.
4. For PX4 uXRCE-DDS, verify the agent and `rt/fmu/out/*` topics before any offboard control test.
5. Keep arming and offboard commands disabled until bench logs show stable telemetry, time sync, and failsafe behavior.

## Practical first build

For the first hardware integration slice, keep it deliberately small:

```text
Raspberry Pi 5
  - Ubuntu 24.04 ARM64
  - ROS 2 Jazzy
  - One CSI or USB camera, compressed image topic
  - One 2D LiDAR publishing /scan
  - Optional USB GNSS publishing /fix

Mac ROS 2 container
  - RDP/RViz
  - check_runtime_networking.sh green
  - CycloneDDS first
  - Zenoh fallback if discovery/routing is unreliable

No flight controller setpoints yet.
No Jetson yet unless perception throughput is already the blocker.
```

This gives the smallest useful proof: the Pi owns physical sensors, the Mac container sees ROS 2 topics over the network, RViz can inspect the real streams, and the next Nav2/SLAM step has measurable `/scan`, image, TF, and timing evidence.
