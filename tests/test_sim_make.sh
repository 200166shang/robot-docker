#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/robot-docker-sim-make.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

cat > "${TEST_ROOT}/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "--test-command-flag" ]] || exit 2
shift
[[ "$#" -eq 3 && "$1" == image && "$2" == inspect ]] || exit 2
case "$3" in
  robot-docker:jazzy-base) [[ -f "${BASE_IMAGE_MARKER}" ]] ;;
  robot-docker:jazzy-sim) [[ -f "${SIM_IMAGE_MARKER}" ]] ;;
  *) exit 2 ;;
esac
SH

cat > "${TEST_ROOT}/compose" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "--test-command-flag" ]] || exit 2
shift
if [[ " $* " == *" config --format json "* ]]; then
  cat <<'JSON'
{"services":{"base":{"image":"robot-docker:jazzy-base"},"sim":{"image":"robot-docker:jazzy-sim"}}}
JSON
elif [[ " $* " == *" build --pull base "* ]]; then
  printf '%s\n' 'build --pull base' >> "${COMPOSE_LOG}"
  touch "${BASE_IMAGE_MARKER}"
elif [[ " $* " == *" build sim "* ]]; then
  [[ -f "${BASE_IMAGE_MARKER}" ]] || exit 3
  printf '%s\n' 'build sim' >> "${COMPOSE_LOG}"
  touch "${SIM_IMAGE_MARKER}"
elif [[ " $* " == *" up -d sim novnc "* ]]; then
  [[ -f "${SIM_IMAGE_MARKER}" ]] || exit 4
  printf '%s\n' 'up -d sim novnc' >> "${COMPOSE_LOG}"
elif [[ " $* " == *" up -d sim "* ]]; then
  [[ -f "${SIM_IMAGE_MARKER}" ]] || exit 4
  printf '%s\n' 'up -d sim' >> "${COMPOSE_LOG}"
elif [[ " $* " == *" exec sim /usr/local/bin/robot-docker-entrypoint bash "* ]]; then
  [[ -f "${SIM_IMAGE_MARKER}" ]] || exit 5
  printf '%s\n' 'exec sim ROS entrypoint bash' >> "${COMPOSE_LOG}"
elif [[ " $* " == *" exec -d sim /usr/local/bin/robot-docker-entrypoint ros2 run turtlesim turtlesim_node "* ]]; then
  [[ -f "${SIM_IMAGE_MARKER}" ]] || exit 5
  printf '%s\n' 'exec -d sim turtlesim' >> "${COMPOSE_LOG}"
elif [[ " $* " == *" exec -d sim /usr/local/bin/robot-docker-entrypoint rviz2 "* ]]; then
  [[ -f "${SIM_IMAGE_MARKER}" ]] || exit 5
  printf '%s\n' 'exec -d sim rviz2' >> "${COMPOSE_LOG}"
elif [[ " $* " == *" exec -d sim /usr/local/bin/robot-docker-entrypoint gz sim "* ]]; then
  [[ -f "${SIM_IMAGE_MARKER}" ]] || exit 5
  printf '%s\n' 'exec -d sim gz sim' >> "${COMPOSE_LOG}"
elif [[ " $* " == *" stop sim novnc "* ]]; then
  printf '%s\n' 'stop sim novnc' >> "${COMPOSE_LOG}"
else
  printf 'unexpected compose invocation: %s\n' "$*" >&2
  exit 2
fi
SH

cat > "${TEST_ROOT}/python" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "--test-command-flag" ]] || exit 2
shift
exec python3 "$@"
SH

chmod +x "${TEST_ROOT}/docker" "${TEST_ROOT}/compose" "${TEST_ROOT}/python"

COMPOSE="${TEST_ROOT}/compose --test-command-flag" \
DOCKER="${TEST_ROOT}/docker --test-command-flag" \
PYTHON="${TEST_ROOT}/python --test-command-flag" \
BASE_IMAGE_MARKER="${TEST_ROOT}/base-built" \
SIM_IMAGE_MARKER="${TEST_ROOT}/sim-built" \
COMPOSE_LOG="${TEST_ROOT}/compose.log" \
  make --no-print-directory sim-build

expected_log=$'build --pull base\nbuild sim'
actual_log="$(cat "${TEST_ROOT}/compose.log")"
[[ "${actual_log}" == "${expected_log}" ]] || {
  echo "FAIL: sim-build did not build the missing base image first" >&2
  exit 1
}

echo 'PASS: sim-build builds a missing base image before the simulation image'

rm -f "${TEST_ROOT}/base-built" "${TEST_ROOT}/sim-built"
: > "${TEST_ROOT}/compose.log"

COMPOSE="${TEST_ROOT}/compose --test-command-flag" \
DOCKER="${TEST_ROOT}/docker --test-command-flag" \
PYTHON="${TEST_ROOT}/python --test-command-flag" \
BASE_IMAGE_MARKER="${TEST_ROOT}/base-built" \
SIM_IMAGE_MARKER="${TEST_ROOT}/sim-built" \
COMPOSE_LOG="${TEST_ROOT}/compose.log" \
  make --no-print-directory sim-shell

expected_log=$'build --pull base\nbuild sim\nup -d sim\nexec sim ROS entrypoint bash'
actual_log="$(cat "${TEST_ROOT}/compose.log")"
[[ "${actual_log}" == "${expected_log}" ]] || {
  echo "FAIL: sim-shell did not build, start, and enter the simulation service" >&2
  exit 1
}

echo 'PASS: sim-shell builds missing images, starts the service, and enters through the ROS entrypoint'

rm -f "${TEST_ROOT}/base-built" "${TEST_ROOT}/sim-built"
: > "${TEST_ROOT}/compose.log"

COMPOSE="${TEST_ROOT}/compose --test-command-flag" \
DOCKER="${TEST_ROOT}/docker --test-command-flag" \
PYTHON="${TEST_ROOT}/python --test-command-flag" \
BASE_IMAGE_MARKER="${TEST_ROOT}/base-built" \
SIM_IMAGE_MARKER="${TEST_ROOT}/sim-built" \
COMPOSE_LOG="${TEST_ROOT}/compose.log" \
  make --no-print-directory sim-up

expected_log=$'build --pull base\nbuild sim\nup -d sim novnc'
actual_log="$(cat "${TEST_ROOT}/compose.log")"
[[ "${actual_log}" == "${expected_log}" ]] || {
  echo "FAIL: sim-up did not build the image and start both runtime services" >&2
  exit 1
}

echo 'PASS: sim-up builds missing images and starts simulation plus browser display services'

rm -f "${TEST_ROOT}/base-built" "${TEST_ROOT}/sim-built"
: > "${TEST_ROOT}/compose.log"

COMPOSE="${TEST_ROOT}/compose --test-command-flag" \
DOCKER="${TEST_ROOT}/docker --test-command-flag" \
PYTHON="${TEST_ROOT}/python --test-command-flag" \
BASE_IMAGE_MARKER="${TEST_ROOT}/base-built" \
SIM_IMAGE_MARKER="${TEST_ROOT}/sim-built" \
COMPOSE_LOG="${TEST_ROOT}/compose.log" \
  make --no-print-directory sim-turtlesim

expected_log=$'build --pull base\nbuild sim\nup -d sim novnc\nexec -d sim turtlesim'
actual_log="$(cat "${TEST_ROOT}/compose.log")"
[[ "${actual_log}" == "${expected_log}" ]] || {
  echo "FAIL: sim-turtlesim did not start the runtime and detached turtlesim process" >&2
  exit 1
}

echo 'PASS: sim-turtlesim starts the browser runtime and a persistent detached GUI process'

: > "${TEST_ROOT}/compose.log"
for target in sim-rviz sim-gazebo; do
  COMPOSE="${TEST_ROOT}/compose --test-command-flag" \
  DOCKER="${TEST_ROOT}/docker --test-command-flag" \
  PYTHON="${TEST_ROOT}/python --test-command-flag" \
  BASE_IMAGE_MARKER="${TEST_ROOT}/base-built" \
  SIM_IMAGE_MARKER="${TEST_ROOT}/sim-built" \
  COMPOSE_LOG="${TEST_ROOT}/compose.log" \
    make --no-print-directory "${target}"
done

expected_log=$'up -d sim novnc\nexec -d sim rviz2\nup -d sim novnc\nexec -d sim gz sim'
actual_log="$(cat "${TEST_ROOT}/compose.log")"
[[ "${actual_log}" == "${expected_log}" ]] || {
  echo "FAIL: sim-rviz and sim-gazebo did not start the expected GUI processes" >&2
  exit 1
}

echo 'PASS: sim-rviz and sim-gazebo start their detached GUI processes'

: > "${TEST_ROOT}/compose.log"
COMPOSE="${TEST_ROOT}/compose --test-command-flag" \
COMPOSE_LOG="${TEST_ROOT}/compose.log" \
  make --no-print-directory sim-down
[[ "$(cat "${TEST_ROOT}/compose.log")" == 'stop sim novnc' ]] || {
  echo "FAIL: sim-down did not stop both simulation services" >&2
  exit 1
}

echo 'PASS: sim-down stops simulation and browser display services'
