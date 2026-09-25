#!/usr/bin/env bash

set -euo pipefail

display="${DISPLAY:-:0}"
geometry="${ROBOT_DOCKER_DISPLAY_GEOMETRY:-1280x800x24}"
vnc_port="${ROBOT_DOCKER_VNC_PORT:-5900}"

# 为容器内 GUI 固定虚拟显示，并载入 VNC 端口探测函数。
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
  # 容器退出或收到停止信号时，按依赖顺序清理 ROS 命令、VNC、窗口管理器和 Xvfb。
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

# 将停止信号转换为正常退出，让 EXIT trap 统一回收后台进程。
trap cleanup EXIT
trap stop_on_signal INT TERM

# 先启动 Xvfb 并等待显示 socket 可用，避免后续 GUI 服务抢跑。
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

# 显示就绪后启动轻量窗口管理器和 VNC 服务，再等待 VNC 端口开始监听。
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

# 显示后端就绪后交给基础镜像 entrypoint 加载 ROS，再运行容器主命令。
/usr/local/bin/robot-docker-entrypoint "$@" &
command_pid=$!
status=0
wait "${command_pid}" || status=$?
exit "${status}"
