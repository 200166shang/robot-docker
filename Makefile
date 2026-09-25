SHELL := /bin/bash

.DEFAULT_GOAL := help

COMPOSE ?= docker compose
PROJECT_NAME ?= robot-docker
ENV_FILE ?= $(if $(wildcard .env),.env,.env.example)
COMPOSE_CMD = $(COMPOSE) --project-name $(PROJECT_NAME) --env-file $(ENV_FILE)

.PHONY: help build build-official up shell smoke test config down

help:
	@printf '%s\n' \
		'robot-docker commands:' \
		'  make build           Build the Jazzy base image with the configured mirror' \
		'  make build-official  Build with the official Ubuntu, ROS, and rosdep sources' \
		'  make up              Start the base service in the background' \
		'  make shell           Open an interactive shell in a disposable container' \
		'  make smoke           Build the image and run the container smoke test' \
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

test:
	bash tests/run.sh

config:
	$(COMPOSE_CMD) config

down:
	$(COMPOSE_CMD) down
