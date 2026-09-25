#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "SMOKE TEST FAILED: $*" >&2
  exit 1
}

[[ "${ROS_DISTRO:-}" == "jazzy" ]] || fail "ROS_DISTRO is not jazzy"
[[ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]] || fail "ROS setup file is missing"

for command_name in \
  ros2 \
  colcon \
  rosdep \
  vcs \
  python3 \
  git \
  cmake \
  ninja \
  gdb \
  rg \
  jq \
  tree; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing command: ${command_name}"
done

ros2 --help >/dev/null
colcon --help >/dev/null
rosdep --version >/dev/null
vcs --help >/dev/null
python3 --version >/dev/null

echo "PASS: ROS 2 Jazzy base environment"
