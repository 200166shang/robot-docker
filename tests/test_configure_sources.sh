#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURE_SOURCES="${ROOT_DIR}/docker/configure-sources.sh"
TEST_ROOT=""

cleanup() {
  if [[ -n "${TEST_ROOT}" && -d "${TEST_ROOT}" ]]; then
    rm -rf "${TEST_ROOT}"
  fi
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  local file="$2"

  grep -Fq -- "${expected}" "${file}" || fail "${file} does not contain: ${expected}"
}

assert_not_contains() {
  local unexpected="$1"
  local file="$2"

  if grep -Fq -- "${unexpected}" "${file}"; then
    fail "${file} unexpectedly contains: ${unexpected}"
  fi
}

new_fixture() {
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/robot-docker-sources.XXXXXX")"
  mkdir -p \
    "${TEST_ROOT}/etc/apt/sources.list.d" \
    "${TEST_ROOT}/etc/robot-docker"

  printf '%s\n' \
    'Types: deb' \
    'URIs: http://archive.ubuntu.com/ubuntu/' \
    'Suites: noble noble-updates noble-security' \
    'Components: main universe' \
    > "${TEST_ROOT}/etc/apt/sources.list.d/ubuntu.sources"

  printf '%s\n' \
    'deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu noble main' \
    'deb-src [arch=amd64,arm64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu noble main' \
    > "${TEST_ROOT}/etc/apt/sources.list.d/ros2.list"

  printf '%s\n' \
    'Types: deb deb-src' \
    'URIs: http://packages.ros.org/ros2/ubuntu' \
    'Suites: noble' \
    'Components: main' \
    'Signed-By: /usr/share/keyrings/ros-archive-keyring.gpg' \
    > "${TEST_ROOT}/etc/apt/sources.list.d/ros2.sources"
}

test_mirror_mode_rewrites_sources_and_persists_rosdep_index() {
  new_fixture

  "${CONFIGURE_SOURCES}" \
    --root "${TEST_ROOT}" \
    --mode mirror \
    --ubuntu-mirror "https://mirrors.example.test/ubuntu" \
    --ros-apt-mirror "https://mirrors.example.test/ros2/ubuntu" \
    --rosdistro-index-url "https://mirrors.example.test/rosdistro/index-v4.yaml" \
    --rosdep-source-mirror "https://mirrors.example.test/github-raw/ros/rosdistro/master"

  assert_contains 'URIs: https://mirrors.example.test/ubuntu' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ubuntu.sources"
  assert_not_contains 'archive.ubuntu.com' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ubuntu.sources"
  assert_contains 'https://mirrors.example.test/ros2/ubuntu' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.list"
  assert_not_contains 'deb-src' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.list"
  assert_contains 'Types: deb' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.sources"
  assert_not_contains 'Types: deb deb-src' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.sources"
  assert_contains 'export ROSDISTRO_INDEX_URL=https://mirrors.example.test/rosdistro/index-v4.yaml' \
    "${TEST_ROOT}/etc/robot-docker/source-env"
  assert_contains 'https://mirrors.example.test/github-raw/ros/rosdistro/master' \
    "${TEST_ROOT}/etc/robot-docker/rosdep-source-mirror"
}

test_mirror_mode_rewrites_multiple_source_files() {
  new_fixture
  cp "${TEST_ROOT}/etc/apt/sources.list.d/ubuntu.sources" \
    "${TEST_ROOT}/etc/apt/sources.list.d/ubuntu-extra.sources"
  cp "${TEST_ROOT}/etc/apt/sources.list.d/ros2.list" \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2-extra.list"

  "${CONFIGURE_SOURCES}" \
    --root "${TEST_ROOT}" \
    --mode mirror \
    --ubuntu-mirror "https://mirrors.example.test/ubuntu" \
    --ros-apt-mirror "https://mirrors.example.test/ros2/ubuntu"

  assert_contains 'URIs: https://mirrors.example.test/ubuntu' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ubuntu-extra.sources"
  assert_contains 'https://mirrors.example.test/ros2/ubuntu' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2-extra.list"
  assert_not_contains 'deb-src' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2-extra.list"
}

test_official_mode_leaves_sources_unchanged_and_clears_runtime_override() {
  new_fixture
  printf '%s\n' \
    'export ROSDISTRO_INDEX_URL=https://mirrors.example.test/rosdistro/index-v4.yaml' \
    > "${TEST_ROOT}/etc/robot-docker/source-env"
  printf '%s\n' \
    'https://mirrors.example.test/github-raw/ros/rosdistro/master' \
    > "${TEST_ROOT}/etc/robot-docker/rosdep-source-mirror"

  "${CONFIGURE_SOURCES}" \
    --root "${TEST_ROOT}" \
    --mode official \
    --ubuntu-mirror "https://mirrors.example.test/ubuntu" \
    --ros-apt-mirror "https://mirrors.example.test/ros2/ubuntu" \
    --rosdistro-index-url "https://mirrors.example.test/rosdistro/index-v4.yaml"

  assert_contains 'archive.ubuntu.com' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ubuntu.sources"
  assert_contains 'packages.ros.org/ros2/ubuntu' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.list"
  assert_contains 'https://packages.ros.org/ros2/ubuntu' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.list"
  assert_not_contains 'http://packages.ros.org/ros2/ubuntu' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.list"
  assert_contains 'deb-src' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.list"
  assert_contains 'Types: deb deb-src' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.sources"
  assert_contains 'https://packages.ros.org/ros2/ubuntu' \
    "${TEST_ROOT}/etc/apt/sources.list.d/ros2.sources"
  assert_not_contains 'ROSDISTRO_INDEX_URL' \
    "${TEST_ROOT}/etc/robot-docker/source-env"
  assert_not_contains 'github-raw' \
    "${TEST_ROOT}/etc/robot-docker/rosdep-source-mirror"
}

test_invalid_mode_fails() {
  new_fixture

  if "${CONFIGURE_SOURCES}" --root "${TEST_ROOT}" --mode invalid; then
    fail 'invalid source mode should fail'
  fi
}

test_mirror_mode_rewrites_sources_and_persists_rosdep_index
test_mirror_mode_rewrites_multiple_source_files
test_official_mode_leaves_sources_unchanged_and_clears_runtime_override
test_invalid_mode_fails

echo 'PASS: configure-sources behavior'
