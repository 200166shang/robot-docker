#!/usr/bin/env bash

set -eo pipefail

# 载入镜像构建时保存的源配置，再载入 ROS 发行版环境。
source_env="${ROBOT_DOCKER_SOURCE_ENV:-/etc/robot-docker/source-env}"
if [[ -f "${source_env}" ]]; then
  # shellcheck disable=SC1090
  source "${source_env}"
fi

source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"

workspace="${WORKSPACE:-/workspace}"
# 若挂载工作区已有 colcon install 结果，也一并加载其 overlay 环境。
if [[ -f "${workspace}/install/setup.bash" ]]; then
  # shellcheck disable=SC1090
  source "${workspace}/install/setup.bash"
fi

# 没有指定命令时给用户交互式 Bash；其余情况原样执行传入命令。
if [[ "$#" -eq 0 ]]; then
  set -- bash
fi

exec "$@"
