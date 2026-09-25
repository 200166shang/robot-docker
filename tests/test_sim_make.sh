#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/robot-docker-sim-make.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

cat > "${TEST_ROOT}/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

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
else
  printf 'unexpected compose invocation: %s\n' "$*" >&2
  exit 2
fi
SH

chmod +x "${TEST_ROOT}/docker" "${TEST_ROOT}/compose"

COMPOSE="${TEST_ROOT}/compose" \
DOCKER="${TEST_ROOT}/docker" \
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
