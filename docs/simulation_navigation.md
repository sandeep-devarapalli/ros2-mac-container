# Simulation and Navigation Testing

Use this guide to test the ROS 2 desktop environment before connecting a physical robot.

## Test Levels

Start small, then add heavier simulation only when the base ROS graph is healthy.

1. ROS graph smoke: `ros2 doctor`, demo talker/listener, rosbridge.
2. GUI smoke: RDP into KDE and launch RViz.
3. Lightweight sim: `turtlesim`.
4. Navigation sim: Nav2 minimal TurtleBot3 or TurtleBot3 Gazebo.

## Base Runtime Smoke

On the Mac:

```bash
./scripts/start_container.sh
./scripts/check_runtime_networking.sh
```

Inside the container:

```bash
source /opt/ros/jazzy/setup.bash
ros2 run demo_nodes_cpp talker
```

In a second container shell:

```bash
source /opt/ros/jazzy/setup.bash
ros2 run demo_nodes_py listener
```

## Turtlesim Smoke

The base image already includes `turtlesim`. Launch it inside the RDP desktop session:

```bash
source /opt/ros/jazzy/setup.bash
ros2 run turtlesim turtlesim_node
```

In another terminal:

```bash
source /opt/ros/jazzy/setup.bash
ros2 run turtlesim turtle_teleop_key
```

This proves ROS topics, keyboard teleop, and GUI forwarding through xrdp before installing heavier simulation packages.

## Optional Nav2 / TurtleBot3 Install

The current image does not install Nav2 or TurtleBot3 by default because the package set is large. The Jazzy apt repository exposes the required packages, including:

```text
ros-jazzy-navigation2
ros-jazzy-nav2-bringup
ros-jazzy-nav2-minimal-tb3-sim
ros-jazzy-slam-toolbox
ros-jazzy-turtlebot3-gazebo
ros-jazzy-turtlebot3-navigation2
ros-jazzy-ros-gz-sim
```

To try navigation in the running container:

```bash
sudo apt-get update
sudo apt-get install -y \
  ros-jazzy-navigation2 \
  ros-jazzy-nav2-bringup \
  ros-jazzy-nav2-minimal-tb3-sim \
  ros-jazzy-slam-toolbox \
  ros-jazzy-turtlebot3-gazebo \
  ros-jazzy-turtlebot3-navigation2 \
  ros-jazzy-ros-gz-sim
```

This is intentionally optional. A simulated install on the current Jazzy image reported about 300 new packages for the full Nav2/TurtleBot3/Gazebo path.

## Navigation Test Path

After installing the optional packages, use RDP and run one terminal per process:

```bash
source /opt/ros/jazzy/setup.bash
export TURTLEBOT3_MODEL=burger
```

Start with the lightest Nav2 simulator package:

```bash
ros2 pkg prefix nav2_minimal_tb3_sim
ros2 launch nav2_minimal_tb3_sim tb3_simulation_launch.py
```

If that launch file is not present in the package version installed on your host, inspect available launch files:

```bash
find /opt/ros/jazzy/share/nav2_minimal_tb3_sim -maxdepth 3 -type f -name '*.py'
```

Then launch RViz in the RDP session:

```bash
rviz2
```

Use RViz to confirm:

- `/map`, `/tf`, `/odom`, `/scan`, and `/cmd_vel` exist.
- The robot model appears.
- Nav2 lifecycle nodes become active.
- A 2D goal in RViz produces a planned path and velocity commands.

## When To Bake It Into The Image

Only add these packages to the Dockerfile after the optional install path is proven on your Mac. Baking them in will make the base image larger and rebuilds slower, so keep the default image focused on ROS desktop, RDP, rosbridge, Zenoh, and transport tooling until navigation simulation is a confirmed workflow.

