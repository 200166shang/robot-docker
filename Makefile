SHELL := /bin/bash

.DEFAULT_GOAL := help

COMPOSE ?= docker compose
DOCKER ?= docker
PYTHON ?= python3
PROJECT_NAME ?= robot-docker
ENV_FILE ?= $(if $(wildcard .env),.env,.env.example)
COMPOSE_CMD = $(COMPOSE) --project-name $(PROJECT_NAME) --env-file $(ENV_FILE)
SIM_TARGET_ARGS = "$(COMPOSE)" "$(DOCKER)" "$(PYTHON)" "$(PROJECT_NAME)" "$(ENV_FILE)"

.PHONY: help build build-official up shell smoke sim-build sim-up sim-open sim-shell sim-turtlesim sim-rviz sim-gazebo sim-down sim-smoke test config down

help:
	@printf '%s\n' \
		'robot-docker commands:' \
		'  make build           Build the Jazzy base image with the configured mirror' \
		'  make build-official  Build with the official Ubuntu, ROS, and rosdep sources' \
		'  make up              Start the base service in the background' \
		'  make shell           Open an interactive shell in a disposable container' \
		'  make smoke           Build the image and run the container smoke test' \
		'  make sim-build       Build the Jazzy simulation image (and base image if missing)' \
		'  make sim-up          Start the simulation and browser display services' \
		'  make sim-open        Print the local browser display URL' \
		'  make sim-shell       Enter the long-running Jazzy simulation service' \
		'  make sim-turtlesim   Start turtlesim in the simulation display' \
		'  make sim-rviz        Start RViz2 in the simulation display' \
		'  make sim-gazebo      Start Gazebo in the simulation display' \
		'  make sim-down        Stop the simulation and browser display services' \
		'  make sim-smoke       Build the simulation image and check commands and display runtime' \
		'  make test            Run local source and Compose configuration tests' \
		'  make config          Show the resolved Compose configuration' \
		'  make down            Stop the Compose services'

build:
	$(COMPOSE_CMD) build --pull base

build-official:
	SOURCE_MODE=official ROSDISTRO_INDEX_URL= $(COMPOSE_CMD) build --pull base

up:
	$(COMPOSE_CMD) up -d base

shell:
	$(COMPOSE_CMD) run --rm --no-deps base bash

smoke: build
	$(COMPOSE_CMD) run --rm --no-deps base /usr/local/bin/robot-docker-smoke-test

sim-build:
	@bash docker/sim-targets.sh build $(SIM_TARGET_ARGS)

sim-up:
	@bash docker/sim-targets.sh up $(SIM_TARGET_ARGS)

sim-open:
	@bash docker/sim-targets.sh open $(SIM_TARGET_ARGS)

sim-shell:
	@bash docker/sim-targets.sh shell $(SIM_TARGET_ARGS)

sim-turtlesim:
	@bash docker/sim-targets.sh turtlesim $(SIM_TARGET_ARGS)

sim-rviz:
	@bash docker/sim-targets.sh rviz $(SIM_TARGET_ARGS)

sim-gazebo:
	@bash docker/sim-targets.sh gazebo $(SIM_TARGET_ARGS)

sim-down:
	$(COMPOSE_CMD) stop sim novnc

sim-smoke: sim-build
	$(COMPOSE_CMD) run --rm --no-deps sim /usr/local/bin/robot-docker-sim-smoke-test

test:
	bash tests/run.sh

config:
	$(COMPOSE_CMD) config

down:
	$(COMPOSE_CMD) down
