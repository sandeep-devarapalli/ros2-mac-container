#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ros2_mac_container}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
INSTALL_NAV2="${INSTALL_NAV2:-0}"
USE_RVIZ="${USE_RVIZ:-0}"
GOAL_TIMEOUT="${GOAL_TIMEOUT:-90}"
RVIZ_DISPLAY="${RVIZ_DISPLAY:-:10}"

NAV2_PACKAGES=(
  "ros-${ROS_DISTRO}-navigation2"
  "ros-${ROS_DISTRO}-nav2-bringup"
  "ros-${ROS_DISTRO}-nav2-loopback-sim"
  "ros-${ROS_DISTRO}-slam-toolbox"
  "ros-${ROS_DISTRO}-turtlebot3-gazebo"
  "ros-${ROS_DISTRO}-turtlebot3-navigation2"
)

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

cleanup_nav2() {
  container exec "${CONTAINER_NAME}" bash -lc \
    "pids=\$(ps -eo pid,args | awk '/tb3_loopback_simulation|component_container_isolated|nav2_loopback_sim|nav2_map_server|nav2_lifecycle_manager|rviz2|ros2 action send_goal \\/navigate_to_pose/ && !/awk/ {print \$1}'); if [ -n \"\$pids\" ]; then kill \$pids 2>/dev/null || true; fi" \
    >/dev/null 2>&1 || true
}

require_command container

if ! container list | awk -v name="${CONTAINER_NAME}" '$1 == name && $5 == "running" { found = 1 } END { exit found ? 0 : 1 }'; then
  echo "Container ${CONTAINER_NAME} is not running." >&2
  echo "Start it with: ./scripts/start_container.sh" >&2
  exit 1
fi

missing_packages="$(
  container exec "${CONTAINER_NAME}" bash -lc "dpkg-query -W -f='\${binary:Package}\\n' ${NAV2_PACKAGES[*]} 2>/dev/null || true" \
    | awk -v packages="${NAV2_PACKAGES[*]}" '
      BEGIN {
        split(packages, wanted, " ");
        for (i in wanted) missing[wanted[i]] = 1;
      }
      { delete missing[$1]; }
      END {
        for (pkg in missing) print pkg;
      }
    '
)"

if [ -n "${missing_packages}" ]; then
  if [ "${INSTALL_NAV2}" = "1" ]; then
    echo "Installing optional Nav2 packages in ${CONTAINER_NAME}:"
    printf '%s\n' "${missing_packages}"
    container exec "${CONTAINER_NAME}" bash -lc "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y ${NAV2_PACKAGES[*]}"
  else
    echo "Missing optional Nav2 packages in ${CONTAINER_NAME}:" >&2
    printf '%s\n' "${missing_packages}" >&2
    echo "Install them with: INSTALL_NAV2=1 $0" >&2
    exit 1
  fi
fi

cleanup_nav2
trap cleanup_nav2 EXIT

ros_exec() {
  container exec --user ros "${CONTAINER_NAME}" bash -lc "source /opt/ros/${ROS_DISTRO}/setup.bash; $*"
}

launch_log="/tmp/nav2-loopback-smoke-launch.log"
goal_log="/tmp/nav2-loopback-smoke-goal.log"
scan_log="/tmp/nav2-loopback-smoke-scan.log"
tf_log="/tmp/nav2-loopback-smoke-final-tf.log"

ros_exec "rm -f ${launch_log} ${goal_log} ${scan_log} ${tf_log}"

use_rviz_arg="False"
rviz_env=""
if [ "${USE_RVIZ}" = "1" ]; then
  use_rviz_arg="True"
  rviz_env="export DISPLAY=${RVIZ_DISPLAY}; export XAUTHORITY=/home/ros/.Xauthority; export QT_X11_NO_MITSHM=1;"
fi

ros_exec "${rviz_env} nohup ros2 launch nav2_bringup tb3_loopback_simulation.launch.py use_rviz:=${use_rviz_arg} >${launch_log} 2>&1 & echo \$! >/tmp/nav2-loopback-smoke-launch.pid"

wait_for_topic() {
  local topic="$1"
  local timeout_seconds="$2"
  local deadline=$((SECONDS + timeout_seconds))
  until ros_exec "ros2 topic list 2>/dev/null | grep -qx '${topic}'"; do
    if [ "${SECONDS}" -ge "${deadline}" ]; then
      echo "Timed out waiting for topic ${topic}" >&2
      container exec "${CONTAINER_NAME}" bash -lc "tail -120 ${launch_log}" >&2 || true
      exit 1
    fi
    sleep 1
  done
}

wait_for_topic "/initialpose" 45

ros_exec "timeout 5 ros2 topic pub --once /initialpose geometry_msgs/msg/PoseWithCovarianceStamped '{header: {frame_id: map}, pose: {pose: {position: {x: -2.0, y: -0.5, z: 0.0}, orientation: {w: 1.0}}}}' >/tmp/nav2-loopback-smoke-initialpose.log"

wait_for_lifecycle() {
  local node="$1"
  local timeout_seconds="$2"
  local deadline=$((SECONDS + timeout_seconds))
  until ros_exec "ros2 lifecycle get '/${node}' 2>/dev/null | grep -q 'active \\[3\\]'"; do
    if [ "${SECONDS}" -ge "${deadline}" ]; then
      echo "Timed out waiting for /${node} to become active" >&2
      container exec "${CONTAINER_NAME}" bash -lc "tail -160 ${launch_log}" >&2 || true
      exit 1
    fi
    sleep 1
  done
}

for node in map_server controller_server smoother_server planner_server behavior_server bt_navigator waypoint_follower velocity_smoother route_server collision_monitor docking_server; do
  wait_for_lifecycle "${node}" 60
done

ros_exec "timeout 5 ros2 topic echo --once /scan >${scan_log}"

ros_exec "timeout ${GOAL_TIMEOUT} ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose '{pose: {header: {frame_id: map}, pose: {position: {x: 2.0, y: 0.0, z: 0.0}, orientation: {w: 1.0}}}}' --feedback >${goal_log} 2>&1"

if ! container exec "${CONTAINER_NAME}" bash -lc "grep -q 'Goal finished with status: SUCCEEDED' ${goal_log}"; then
  echo "Nav2 loopback goal did not succeed." >&2
  container exec "${CONTAINER_NAME}" bash -lc "tail -160 ${goal_log}" >&2 || true
  container exec "${CONTAINER_NAME}" bash -lc "tail -160 ${launch_log}" >&2 || true
  exit 1
fi

ros_exec "timeout 4 ros2 run tf2_ros tf2_echo map base_link >${tf_log} 2>&1 || true"

echo "OK: Nav2 lifecycle nodes reached active."
echo "OK: /scan produced a sample."
echo "OK: NavigateToPose succeeded."
container exec "${CONTAINER_NAME}" bash -lc "grep -A12 'Result:' ${goal_log}" || true
container exec "${CONTAINER_NAME}" bash -lc "grep -m1 'Translation:' ${tf_log}" || true
echo "Logs:"
echo "  ${launch_log}"
echo "  ${goal_log}"
echo "  ${tf_log}"

echo "Nav2 loopback smoke passed for ${CONTAINER_NAME}."
