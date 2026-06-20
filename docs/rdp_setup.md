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

Or use FreeRDP's SDL client:

```bash
sdl-freerdp /v:127.0.0.1:3389 /u:ros /p:ros /cert:ignore /size:1280x800 /dynamic-resolution
```

The `/p` flag exposes the password to the local process list. It is acceptable for the default local `ros` test account, but avoid it for real credentials.

Inside KDE, open Konsole and verify ROS:

```bash
source /opt/ros/jazzy/setup.bash
ros2 doctor
rviz2
```

If the KDE session locks, unlock it with password `ros`.

If the RDP session does not open, check logs:

```bash
container logs ros2_mac_container
```
