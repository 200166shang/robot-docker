#!/usr/bin/env bash

set -eo pipefail

source_env="${ROBOT_DOCKER_SOURCE_ENV:-/etc/robot-docker/source-env}"
if [[ -f "${source_env}" ]]; then
  # shellcheck disable=SC1090
  source "${source_env}"
fi

source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"

workspace="${WORKSPACE:-/workspace}"
if [[ -f "${workspace}/install/setup.bash" ]]; then
  # shellcheck disable=SC1090
  source "${workspace}/install/setup.bash"
fi

if [[ "$#" -eq 0 ]]; then
  set -- bash
fi

exec "$@"
