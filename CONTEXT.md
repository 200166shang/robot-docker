# Project Context

## Repository purpose

`robot-docker` maintains reusable ROS 2 development environments. It does not
maintain ROS learning code, robot applications, or a permanent application
workspace.

## Domain terms

### Base image

The general ROS 2 Jazzy development environment. It provides command-line,
build, debugging, Python, and ROS workspace capabilities without simulation
or GUI-specific dependencies.

### Simulation image

An environment layer built on the base image for local GUI-based ROS practice.
Its first scope is Gazebo, RViz, turtlesim, and the GUI runtime needed to use
them. It does not represent a particular robot or navigation stack.

### Simulation service

The long-running container that owns the ROS simulation processes and their
virtual display runtime. Gazebo, RViz, and turtlesim are processes in this
service rather than separate containers.

### Browser display service

The local access layer that exposes the simulation service's virtual desktop
through a browser. It is not a ROS environment and does not own the simulation
processes.

### Mounted scenario workspace

A user-provided ROS workspace or small demonstration directory mounted into a
container for validation or learning. It remains outside the environment
repository's image definition.

### Robot-specific environment

An environment layer that adds a particular robot model or navigation stack,
such as TurtleBot3 and Nav2. It is intentionally separate from the generic
simulation image.
