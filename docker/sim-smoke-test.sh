#!/usr/bin/env bash

set -euo pipefail

# 载入与 entrypoint 共用的 VNC 端口检查函数。
source /usr/local/lib/robot-docker-sim-display-utils.sh

fail() {
  echo "SIMULATION SMOKE TEST FAILED: $*" >&2
  exit 1
}

# 与交互 shell 一样检查 Jazzy 环境，并确认仿真应用和显示后端命令已安装。
[[ "${ROS_DISTRO:-}" == "jazzy" ]] || fail "ROS_DISTRO is not jazzy"
[[ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]] || fail "ROS setup file is missing"

for command_name in \
  gz \
  rviz2 \
  Xvfb \
  x11vnc \
  openbox \
  xdpyinfo; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing command: ${command_name}"
done

check_ros_executable() {
  local package_name="$1"
  local executable_name="$2"

  ros2 pkg executables "${package_name}" \
    | awk -v package="${package_name}" -v executable="${executable_name}" \
        '$1 == package && $2 == executable { found = 1 } END { exit !found }' \
    || fail "missing ROS executable: ${package_name} ${executable_name}"
}

# ROS 可执行文件通过 `ros2 run` 注册，不一定直接位于 PATH，因此从 ROS 包索引核对。
check_ros_executable turtlesim turtlesim_node
check_ros_executable demo_nodes_cpp talker
check_ros_executable demo_nodes_cpp listener
check_ros_executable demo_nodes_py talker
check_ros_executable demo_nodes_py listener

# 清空当前进程继承的 ROS 标记后再经 entrypoint 开新 shell，验证 shell 自己能加载 Jazzy。
env -u AMENT_PREFIX_PATH -u ROS_DISTRO \
  /usr/local/bin/robot-docker-entrypoint bash -c \
  '[[ "${ROS_DISTRO:-}" == "jazzy" ]] && command -v ros2 >/dev/null 2>&1' \
  || fail "the simulation shell does not source the ROS 2 Jazzy environment"

# 确认虚拟显示、窗口管理器和 VNC 正在运行，而不只检查安装包名。
gz sim --help >/dev/null 2>&1 || fail "gz sim is unavailable"
xdpyinfo -display "${DISPLAY:-:0}" >/dev/null 2>&1 || fail "Xvfb display is unavailable"
pgrep -x openbox >/dev/null 2>&1 || fail "Openbox is not running"
pgrep -x x11vnc >/dev/null 2>&1 || fail "x11vnc is not running"

vnc_port="${ROBOT_DOCKER_VNC_PORT:-5900}"
robot_docker_sim_vnc_port_is_listening "${vnc_port}" \
  || fail "VNC server is not listening on port ${vnc_port}"

echo "PASS: ROS 2 Jazzy simulation commands and display runtime"
