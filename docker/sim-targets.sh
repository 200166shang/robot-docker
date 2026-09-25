#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: sim-targets.sh build|shell COMPOSE_COMMAND DOCKER_COMMAND PYTHON_COMMAND PROJECT_NAME ENV_FILE" >&2
  exit 2
}

[[ "$#" -eq 6 ]] || usage

action="$1"
compose_spec="$2"
docker_spec="$3"
python_spec="$4"
project_name="$5"
env_file="$6"

# Makefile 的三个命令配置都允许包含多个词（例如 `docker compose` 或 `sudo docker`）。
compose_command=()
docker_command=()
python_command=()
read -r -a compose_command <<< "${compose_spec}"
read -r -a docker_command <<< "${docker_spec}"
read -r -a python_command <<< "${python_spec}"
[[ "${#compose_command[@]}" -gt 0 ]] || usage
[[ "${#docker_command[@]}" -gt 0 ]] || usage
[[ "${#python_command[@]}" -gt 0 ]] || usage

compose() {
  "${compose_command[@]}" \
    --project-name "${project_name}" \
    --env-file "${env_file}" \
    "$@"
}

image_for_service() {
  local service_name="$1"

  # 读取 Compose 展开的镜像名，继续尊重 .env 中对基础镜像和仿真镜像的覆写。
  compose config --format json \
    | "${python_command[@]}" -c \
        'import json, sys; print(json.load(sys.stdin)["services"][sys.argv[1]]["image"])' \
        "${service_name}"
}

build_simulation_image() {
  local base_image
  base_image="$(image_for_service base)"

  # 仅在基础镜像标签不存在时构建基础层，随后构建基于它的仿真层。
  if ! "${docker_command[@]}" image inspect "${base_image}" >/dev/null 2>&1; then
    compose build --pull base
  fi
  compose build sim
}

open_simulation_shell() {
  local sim_image
  sim_image="$(image_for_service sim)"

  # 仿真镜像缺失时复用同一构建流程，再启动长期服务并进入容器。
  if ! "${docker_command[@]}" image inspect "${sim_image}" >/dev/null 2>&1; then
    build_simulation_image
  fi
  compose up -d sim

  # docker compose exec 不会重新执行容器 ENTRYPOINT；显式调用 ROS entrypoint 为新 shell 加载 Jazzy。
  compose exec sim /usr/local/bin/robot-docker-entrypoint bash
}

case "${action}" in
  build)
    build_simulation_image
    ;;
  shell)
    open_simulation_shell
    ;;
  *)
    usage
    ;;
esac
