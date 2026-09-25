# syntax=docker/dockerfile:1

ARG BASE_IMAGE=ros:jazzy-ros-base

FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG ROS_DISTRO=jazzy
ARG SOURCE_MODE=official
ARG UBUNTU_MIRROR_AMD64=
ARG UBUNTU_MIRROR_ARM64=
ARG ROS_APT_MIRROR=
ARG ROSDISTRO_INDEX_URL=
ARG ROSDEP_SOURCE_MIRROR=

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ROS_DISTRO=${ROS_DISTRO} \
    WORKSPACE=/workspace \
    ROBOT_DOCKER_SOURCE_ENV=/etc/robot-docker/source-env

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY docker/configure-sources.sh /usr/local/bin/robot-docker-configure-sources
COPY docker/entrypoint.sh /usr/local/bin/robot-docker-entrypoint
COPY docker/smoke-test.sh /usr/local/bin/robot-docker-smoke-test

RUN chmod +x \
      /usr/local/bin/robot-docker-configure-sources \
      /usr/local/bin/robot-docker-entrypoint \
      /usr/local/bin/robot-docker-smoke-test

RUN set -euo pipefail; \
    architecture="$(dpkg --print-architecture)"; \
    case "${architecture}" in \
      amd64) ubuntu_mirror="${UBUNTU_MIRROR_AMD64}" ;; \
      arm64) ubuntu_mirror="${UBUNTU_MIRROR_ARM64}" ;; \
      *) \
        if [[ "${SOURCE_MODE}" == "mirror" ]]; then \
          echo "Mirror source configuration does not support architecture: ${architecture}" >&2; \
          exit 1; \
        fi; \
        ubuntu_mirror=""; \
        ;; \
    esac; \
    robot-docker-configure-sources \
      --mode "${SOURCE_MODE}" \
      --ubuntu-mirror "${ubuntu_mirror}" \
      --ros-apt-mirror "${ROS_APT_MIRROR}" \
      --rosdistro-index-url "${ROSDISTRO_INDEX_URL}" \
      --rosdep-source-mirror "${ROSDEP_SOURCE_MIRROR}"; \
    apt-get -o APT::Update::Error-Mode=any update; \
    apt-get install -y --no-install-recommends \
      bash-completion \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      dnsutils \
      file \
      gdb \
      git \
      iproute2 \
      iputils-ping \
      jq \
      less \
      nano \
      netcat-openbsd \
      ninja-build \
      pkg-config \
      procps \
      psmisc \
      python3-dev \
      python3-pip \
      python3-rosdep \
      python3-venv \
      python3-vcstool \
      python3-colcon-common-extensions \
      ripgrep \
      ros-dev-tools \
      tree \
      unzip \
      vim-tiny \
      wget \
      zip; \
    if [[ "${SOURCE_MODE}" == "mirror" && -s /etc/robot-docker/rosdep-source-mirror ]]; then \
      mkdir -p /etc/ros/rosdep/sources.list.d; \
      rosdep_source_mirror="$(cat /etc/robot-docker/rosdep-source-mirror)"; \
      curl --fail --silent --show-error --location --retry 3 \
        "${rosdep_source_mirror}/rosdep/sources.list.d/20-default.list" \
        --output /etc/ros/rosdep/sources.list.d/20-default.list; \
    elif [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then \
      rosdep init; \
    fi; \
    if [[ -s "${ROBOT_DOCKER_SOURCE_ENV}" ]]; then \
      source "${ROBOT_DOCKER_SOURCE_ENV}"; \
    fi; \
    rosdep update; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

WORKDIR ${WORKSPACE}

ENTRYPOINT ["/usr/local/bin/robot-docker-entrypoint"]
CMD ["sleep", "infinity"]
