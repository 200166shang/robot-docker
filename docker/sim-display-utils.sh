#!/usr/bin/env bash

robot_docker_sim_vnc_port_is_listening() {
  local port="$1"

  ss -ltnH \
    | awk -v port=":${port}" '$4 ~ port "$" { found = 1 } END { exit !found }'
}
