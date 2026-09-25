#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

config_json="$(env -u DISPLAY docker compose --project-name robot-docker --env-file .env.example config --format json)"
CONFIG_JSON="${config_json}" python3 - <<'PY'
import json
import os
import sys


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


config = json.loads(os.environ["CONFIG_JSON"])
services = config.get("services", {})
base = services.get("base")
sim = services.get("sim")

if base is None or sim is None:
    fail("base and sim services must both be present")
if base.get("image") != "robot-docker:jazzy-base":
    fail("the base image name changed")
if base.get("build", {}).get("dockerfile") != "Dockerfile":
    fail("the base service must keep using Dockerfile")
if base.get("command") != ["sleep", "infinity"]:
    fail("the base service command changed")

if sim.get("image") != "robot-docker:jazzy-sim":
    fail("the simulation image must use robot-docker:jazzy-sim by default")
build = sim.get("build", {})
if build.get("dockerfile") != "Dockerfile.sim":
    fail("the simulation service must use Dockerfile.sim")
if build.get("args", {}).get("BASE_IMAGE") != "robot-docker:jazzy-base":
    fail("the simulation image must be based on the base image")
if sim.get("command") != ["sleep", "infinity"]:
    fail("the simulation service must remain long-running")
if sim.get("stdin_open") is not True or sim.get("tty") is not True:
    fail("the simulation service must support an interactive shell")
if sim.get("environment", {}).get("DISPLAY") != ":0":
    fail("the simulation service must use its virtual display")
if sim.get("expose") != ["5900"]:
    fail("the VNC backend must be available on the Compose network")
if sim.get("ports"):
    fail("the VNC backend must not be published to the host")
if not any(volume.get("target") == "/workspace" for volume in sim.get("volumes", [])):
    fail("the simulation service must mount the shared workspace")

print("PASS: simulation Compose contract")
PY
