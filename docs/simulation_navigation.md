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

## Optional TurtleBot Gazebo Install

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

Start with the smallest proven Gazebo/TurtleBot path in the running container:

```bash
sudo apt-get update
sudo apt-get install -y ros-jazzy-nav2-minimal-tb3-sim
```

This is intentionally optional. The minimal package added `164` packages, downloaded `131 MB`, and used about `555 MB` of additional disk in the live container. A full Nav2/TurtleBot3 path will be larger.

## Minimal Gazebo Bridge Test Path

The verified Jazzy `nav2_minimal_tb3_sim` package provides Gazebo assets and a spawn/bridge launch. It does not provide a full Nav2 bringup launch in this package version.

Create the headless world:

```bash
source /opt/ros/jazzy/setup.bash
xacro /opt/ros/jazzy/share/nav2_minimal_tb3_sim/worlds/tb3_sandbox.sdf.xacro headless:=true > /tmp/tb3_sandbox_headless.sdf
```

Start Gazebo server-only mode:

```bash
source /opt/ros/jazzy/setup.bash
export GZ_SIM_RESOURCE_PATH=/opt/ros/jazzy/share/nav2_minimal_tb3_sim/models:/opt/ros/jazzy/share
ros2 launch ros_gz_sim gz_sim.launch.py gz_args:="-r -s /tmp/tb3_sandbox_headless.sdf"
```

In a second terminal, spawn the robot and bridge topics:

```bash
source /opt/ros/jazzy/setup.bash
export GZ_SIM_RESOURCE_PATH=/opt/ros/jazzy/share/nav2_minimal_tb3_sim/models:/opt/ros/jazzy/share
ros2 launch nav2_minimal_tb3_sim spawn_tb3.launch.py
```

Confirm bridge topics:

```bash
ros2 topic list | grep -E '^/(clock|cmd_vel|imu|joint_states|odom|scan|tf)$'
```

Drive the simulated robot:

```bash
ros2 topic echo --once /odom
ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.2}, angular: {z: 0.4}}"
sleep 3
ros2 topic echo --once /odom
```

If odometry changes after the command, the Gazebo bridge path is healthy.

Gazebo may warn that its internal transport selected `127.0.0.1` because it could not find a preferred IP. That did not block local in-container simulation during verification, but do not treat Gazebo transport itself as the remote robot networking path until that warning is resolved.

## Full Nav2 Test Path

Only after the minimal bridge works, install full navigation packages:

```bash
sudo apt-get install -y \
  ros-jazzy-navigation2 \
  ros-jazzy-nav2-bringup \
  ros-jazzy-slam-toolbox \
  ros-jazzy-turtlebot3-gazebo \
  ros-jazzy-turtlebot3-navigation2
```

Then use RDP and RViz to confirm:

- `/map`, `/tf`, `/odom`, `/scan`, and `/cmd_vel` exist.
- The robot model appears.
- Nav2 lifecycle nodes become active.
- A 2D goal in RViz produces a planned path and velocity commands.

## When To Bake It Into The Image

Only add these packages to the Dockerfile after the optional install path is proven on your Mac. Baking them in will make the base image larger and rebuilds slower, so keep the default image focused on ROS desktop, RDP, rosbridge, Zenoh, and transport tooling until navigation simulation is a confirmed workflow.
