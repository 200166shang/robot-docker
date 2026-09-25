#!/usr/bin/env bash

set -euo pipefail

# 这些变量保存命令行配置；测试时可用 --root 把文件改写限制在临时目录内。
ROOT="${ROBOT_DOCKER_SOURCE_ROOT:-/}"
MODE="official"
UBUNTU_MIRROR=""
ROS_APT_MIRROR=""
ROSDISTRO_INDEX_URL=""
ROSDEP_SOURCE_MIRROR=""

usage() {
  cat <<'EOF'
Usage: configure-sources.sh [options]

Options:
  --root PATH                 Root directory used for source files (tests only)
  --mode official|mirror     Source mode (default: official)
  --ubuntu-mirror URL        Ubuntu mirror for the current container architecture
  --ros-apt-mirror URL       ROS 2 APT mirror
  --rosdistro-index-url URL  rosdep rosdistro index URL
  --rosdep-source-mirror URL rosdep source-list mirror
EOF
}

# 先完整解析参数并校验模式，再统一修改 APT 源和运行时 rosdep 配置。
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --root)
      [[ "$#" -ge 2 ]] || { echo "--root requires a value" >&2; exit 2; }
      ROOT="$2"
      shift 2
      ;;
    --mode)
      [[ "$#" -ge 2 ]] || { echo "--mode requires a value" >&2; exit 2; }
      MODE="$2"
      shift 2
      ;;
    --ubuntu-mirror)
      [[ "$#" -ge 2 ]] || { echo "--ubuntu-mirror requires a value" >&2; exit 2; }
      UBUNTU_MIRROR="$2"
      shift 2
      ;;
    --ros-apt-mirror)
      [[ "$#" -ge 2 ]] || { echo "--ros-apt-mirror requires a value" >&2; exit 2; }
      ROS_APT_MIRROR="$2"
      shift 2
      ;;
    --rosdistro-index-url)
      [[ "$#" -ge 2 ]] || { echo "--rosdistro-index-url requires a value" >&2; exit 2; }
      ROSDISTRO_INDEX_URL="$2"
      shift 2
      ;;
    --rosdep-source-mirror)
      [[ "$#" -ge 2 ]] || { echo "--rosdep-source-mirror requires a value" >&2; exit 2; }
      ROSDEP_SOURCE_MIRROR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  official|mirror)
    ;;
  *)
    echo "Unsupported source mode: ${MODE}" >&2
    exit 2
    ;;
esac

if [[ "$ROOT" != "/" ]]; then
  ROOT="${ROOT%/}"
fi

# 把容器绝对路径映射到可替换根目录，便于生产环境和无副作用测试共用逻辑。
path_in_root() {
  local path="$1"

  if [[ "$ROOT" == "/" ]]; then
    printf '/%s\n' "${path#/}"
  else
    printf '%s/%s\n' "$ROOT" "${path#/}"
  fi
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\\&#]/\\&/g'
}

replace_in_file() {
  local file="$1"
  local pattern="$2"
  local replacement
  replacement="$(escape_sed_replacement "${3%/}")"

  if sed --version >/dev/null 2>&1; then
    sed -i -E "s#${pattern}#${replacement}#g" "$file"
  else
    sed -i '' -E "s#${pattern}#${replacement}#g" "$file"
  fi
}

# 同时发现传统 .list 和 deb822 .sources 文件，兼容 Ubuntu 与 ROS 仓库的不同格式。
source_files() {
  local apt_dir
  apt_dir="$(path_in_root /etc/apt)"

  SOURCE_FILES=()
  if [[ -f "${apt_dir}/sources.list" ]]; then
    SOURCE_FILES+=("${apt_dir}/sources.list")
  fi

  if [[ -d "${apt_dir}/sources.list.d" ]]; then
    local file
    for file in "${apt_dir}/sources.list.d"/*.list "${apt_dir}/sources.list.d"/*.sources; do
      if [[ -f "$file" ]]; then
        SOURCE_FILES+=("$file")
      fi
    done
  fi
}

# 镜像模式仅替换官方 Ubuntu / ROS 仓库 URL；不匹配时失败，避免构建悄悄沿用错误源。
rewrite_ubuntu_sources() {
  local mirror="${1%/}"
  local matched=0
  local file

  source_files
  for file in "${SOURCE_FILES[@]}"; do
    if grep -Eqi 'archive\.ubuntu\.com/ubuntu|security\.ubuntu\.com/ubuntu|ports\.ubuntu\.com/ubuntu-ports' "$file"; then
      replace_in_file \
        "$file" \
        'https?://(archive|security)\.ubuntu\.com/ubuntu/?|https?://ports\.ubuntu\.com/ubuntu-ports/?' \
        "$mirror"
      matched=1
    fi
  done

  if [[ "$matched" -eq 0 ]]; then
    echo "Could not find an Ubuntu source configured by the official base image" >&2
    return 1
  fi
}

rewrite_ros_sources() {
  local mirror="${1%/}"
  local matched=0
  local file

  source_files
  for file in "${SOURCE_FILES[@]}"; do
    if grep -Eqi 'packages\.ros\.org/ros2/ubuntu' "$file"; then
      replace_in_file \
        "$file" \
        'https?://packages\.ros\.org/ros2/ubuntu/?' \
        "$mirror"
      disable_ros_source_packages "$file"
      matched=1
    fi
  done

  if [[ "$matched" -eq 0 ]]; then
    echo "Could not find a ROS 2 APT source configured by the base image" >&2
    return 1
  fi
}

normalize_official_ros_sources() {
  local file

  source_files
  for file in "${SOURCE_FILES[@]}"; do
    if grep -Eqi 'http://packages\.ros\.org/ros2/ubuntu' "$file"; then
      replace_in_file \
        "$file" \
        'http://packages\.ros\.org/ros2/ubuntu/?' \
        'https://packages.ros.org/ros2/ubuntu'
    fi
  done
}

disable_ros_source_packages() {
  local file="$1"
  local types_pattern='^([[:space:]]*Types:[[:space:]]*)[^#]*deb-src[^#]*$'
  local list_pattern='^[[:space:]]*deb-src[[:space:]]'
  local types_replacement='\1deb'

  if sed --version >/dev/null 2>&1; then
    sed -i -E \
      -e "s#${types_pattern}#${types_replacement}#g" \
      -e "/${list_pattern}/d" \
      "$file"
  else
    sed -i '' -E \
      -e "s#${types_pattern}#${types_replacement}#g" \
      -e "/${list_pattern}/d" \
      "$file"
  fi
}

# rosdep 的索引和源列表配置独立于 APT；把运行时需要的覆写写入 entrypoint 会读取的文件。
write_runtime_source_env() {
  local env_file
  local rosdep_mirror_file
  env_file="$(path_in_root /etc/robot-docker/source-env)"
  rosdep_mirror_file="$(path_in_root /etc/robot-docker/rosdep-source-mirror)"
  mkdir -p "$(dirname "$env_file")"
  : > "$env_file"
  : > "$rosdep_mirror_file"

  if [[ "$MODE" == "mirror" && -n "$ROSDISTRO_INDEX_URL" ]]; then
    printf 'export ROSDISTRO_INDEX_URL=%q\n' "$ROSDISTRO_INDEX_URL" > "$env_file"
  fi

  if [[ "$MODE" == "mirror" && -n "$ROSDEP_SOURCE_MIRROR" ]]; then
    printf '%s\n' "${ROSDEP_SOURCE_MIRROR%/}" > "$rosdep_mirror_file"
  fi
}

# 主流程按模式选择镜像替换或恢复官方 ROS HTTPS 地址，最后保存运行时配置。
if [[ "$MODE" == "mirror" ]]; then
  if [[ -n "$UBUNTU_MIRROR" ]]; then
    rewrite_ubuntu_sources "$UBUNTU_MIRROR"
  fi

  if [[ -n "$ROS_APT_MIRROR" ]]; then
    rewrite_ros_sources "$ROS_APT_MIRROR"
  fi
else
  normalize_official_ros_sources
fi

write_runtime_source_env

echo "Configured package sources in ${MODE} mode"
