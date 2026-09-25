#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

bash tests/test_configure_sources.sh
bash tests/test_sim_compose.sh
bash tests/test_sim_make.sh
bash -n docker/*.sh tests/*.sh
docker compose --env-file .env.example config --quiet

echo 'PASS: local repository checks'
