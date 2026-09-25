# ADR 0001: Add a Separate GUI Simulation Environment Layer

- Status: Accepted
- Date: 2026-09-25

## Context

The repository already provides a reusable ROS 2 Jazzy base image. The next
environment must support Gazebo, RViz, and turtlesim for local learning on
macOS, while keeping TurtleBot3 and Nav2 out of the generic layer.

The repository is an environment-maintenance project. Source code used for a
learning exercise or visual acceptance scenario should be mounted from
outside the image rather than copied into the image during its build.

## Decision

Create a `jazzy-sim` image as a separate layer built from
`robot-docker:jazzy-base`.

The image will use ROS binary packages and will provide the GUI applications
and their runtime dependencies. It will not clone or compile downstream
learning workspaces during the image build.

Compose will manage a simulation service and a separate browser display
service in the same Compose project. The simulation service owns the ROS GUI
processes and virtual display/VNC backend. The browser display service
provides the local noVNC web endpoint and is the only service exposed to the
host browser. The first version is single-user and local-only, with no
authentication, HTTPS, or remote-access contract.

The existing base service interface remains unchanged. Simulation-specific
operations use separate `sim-*` Make targets. Gazebo, RViz, and turtlesim are
started on demand rather than automatically at container startup.

Validation has two parts: automated checks for commands, services, and the
browser endpoint; and a local visual acceptance run using a mounted scenario
workspace. The scenario workspace and its screenshots/logs are validation
artifacts, not source maintained by the environment image repository.

## Alternatives considered

### Add simulation packages to the base image

Rejected. This makes every user pay for GUI and simulation dependencies and
couples the general development environment to a particular use case.

### Put TurtleBot3 and Nav2 in the first simulation layer

Rejected. Robot models and navigation packages have their own assumptions and
will be added as a later robot-specific layer.

### Build downstream source code into the image

Rejected. It makes environment rebuilds slow and couples image maintenance to
learning/application code.

### Use the host's native display as the first macOS contract

Rejected for the first version. Browser-based local access is easier to make
portable and avoids making X11 host configuration part of the initial user
workflow.

## Consequences

The first simulation image is larger than the base image and requires a
browser display service. The browser path adds a small framebuffer transport
overhead, but keeps the ROS environment and display access responsibilities
separate. The initial performance target is stable use of simple scenes, not
high-frame-rate or GPU-accelerated simulation.

The next robot-specific layer can reuse the simulation image without changing
the base image or its user-facing commands.
