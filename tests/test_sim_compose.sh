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
novnc = services.get("novnc")

if base is None or sim is None or novnc is None:
    fail("base, sim, and novnc services must all be present")
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

if novnc.get("image") != "bonigarcia/novnc:1.3.0@sha256:a5be468dc8967a55ffe870e809fa36dbbfc19b67d8156c1e7cb2d26aaa4f32c2":
    fail("the browser display service must use the digest-pinned noVNC image")
if novnc.get("platform") != "linux/amd64":
    fail("the noVNC image must use its published platform")
dependency = novnc.get("depends_on", {}).get("sim", {})
if dependency.get("condition") != "service_healthy":
    fail("the browser display service must wait for the simulation VNC backend")
if novnc.get("environment", {}).get("VNC_SERVER") != "sim:5900":
    fail("the browser display service must target the internal simulation VNC server")
if novnc.get("environment", {}).get("AUTOCONNECT") not in (True, "true"):
    fail("the browser display service must connect automatically")
ports = novnc.get("ports", [])
if len(ports) != 1:
    fail("the browser display service must publish only the noVNC web port")
port = ports[0]
if port.get("target") != 6080 or port.get("published") != "6080":
    fail("the noVNC web port must default to host port 6080")
if port.get("host_ip") != "127.0.0.1":
    fail("the noVNC web port must only bind to the local host")
if not sim.get("healthcheck", {}).get("test"):
    fail("the simulation service must report when its VNC backend is ready")

print("PASS: simulation Compose contract")
PY
