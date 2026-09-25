#!/usr/bin/env bash

robot_docker_sim_vnc_port_is_listening() {
  local port="$1"

  # 只匹配指定 TCP 监听端口，供启动等待和 smoke 检查共享同一判定。
  ss -ltnH \
    | awk -v port=":${port}" '$4 ~ port "$" { found = 1 } END { exit !found }'
}
