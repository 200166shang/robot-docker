#!/usr/bin/env bash

set -euo pipefail

display="${DISPLAY:-:0}"
geometry="${ROBOT_DOCKER_DISPLAY_GEOMETRY:-1280x800x24}"
vnc_port="${ROBOT_DOCKER_VNC_PORT:-5900}"

export DISPLAY="${display}"
source /usr/local/lib/robot-docker-sim-display-utils.sh

xvfb_pid=""
window_manager_pid=""
vnc_pid=""
command_pid=""

fail() {
  echo "SIMULATION DISPLAY FAILED: $*" >&2
  exit 1
}

cleanup() {
  trap - EXIT INT TERM
  local pid

  for pid in "${command_pid}" "${vnc_pid}" "${window_manager_pid}" "${xvfb_pid}"; do
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
    fi
  done

  for pid in "${command_pid}" "${vnc_pid}" "${window_manager_pid}" "${xvfb_pid}"; do
    if [[ -n "${pid}" ]]; then
      wait "${pid}" 2>/dev/null || true
    fi
  done
}

stop_on_signal() {
  exit 143
}

trap cleanup EXIT
trap stop_on_signal INT TERM

Xvfb "${display}" \
  -screen 0 "${geometry}" \
  -nolisten tcp \
  -noreset \
  +extension GLX \
  +render &
xvfb_pid=$!

display_ready=false
for _ in {1..50}; do
  if ! kill -0 "${xvfb_pid}" 2>/dev/null; then
    fail "Xvfb exited before display ${display} became available"
  fi
  if xdpyinfo -display "${display}" >/dev/null 2>&1; then
    display_ready=true
    break
  fi
  sleep 0.1
done
[[ "${display_ready}" == true ]] || fail "timed out waiting for display ${display}"

openbox --sm-disable &
window_manager_pid=$!

x11vnc \
  -display "${display}" \
  -forever \
  -shared \
  -nopw \
  -xkb \
  -listen 0.0.0.0 \
  -rfbport "${vnc_port}" &
vnc_pid=$!

vnc_ready=false
for _ in {1..50}; do
  if ! kill -0 "${vnc_pid}" 2>/dev/null; then
    fail "x11vnc exited before port ${vnc_port} became available"
  fi
  if robot_docker_sim_vnc_port_is_listening "${vnc_port}"; then
    vnc_ready=true
    break
  fi
  sleep 0.1
done
[[ "${vnc_ready}" == true ]] || fail "timed out waiting for VNC port ${vnc_port}"

/usr/local/bin/robot-docker-entrypoint "$@" &
command_pid=$!
status=0
wait "${command_pid}" || status=$?
exit "${status}"
