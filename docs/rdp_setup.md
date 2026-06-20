# RDP Setup

Start the container:

```bash
./scripts/start_container.sh
```

Open Microsoft Remote Desktop on macOS:

```text
PC name: 127.0.0.1:3389
User account: ros
Password: ros
```

Inside KDE, open Konsole and verify ROS:

```bash
source /opt/ros/jazzy/setup.bash
ros2 doctor
rviz2
```

If the RDP session does not open, check logs:

```bash
container logs ros2_mac_container
```

