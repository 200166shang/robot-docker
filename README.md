# robot-docker

用于维护可复用 ROS 2 Docker 环境的仓库。这里维护的是环境，不维护 ROS 学习代码、机器人应用或具体工作区。

第一阶段提供一个 ROS 2 Jazzy 基础开发镜像，后续再基于它增加 Gazebo、RViz、TurtleBot3 和 Nav2 等独立环境。

## 快速开始

要求本机已安装 Docker Desktop 或 Colima，并且 Docker daemon 正在运行。

```bash
make build
make smoke
make shell
```

`make build` 会优先读取本地 `.env`；如果 `.env` 不存在，则使用仓库提交的默认配置。默认配置使用国内镜像源，以减少首次构建的下载时间。

常用命令：

| 命令 | 作用 |
| --- | --- |
| `make build` | 使用默认镜像配置构建基础镜像 |
| `make build-official` | 使用官方 Ubuntu、ROS 和 rosdep 源构建 |
| `make smoke` | 构建镜像并运行基础环境检查 |
| `make shell` | 启动一次性容器并进入交互式 Shell |
| `make up` | 后台启动基础服务 |
| `make config` | 查看 Compose 展开的配置 |
| `make down` | 停止 Compose 服务 |
| `make test` | 运行本地源配置和 Compose 静态检查 |

## 镜像源配置

Ubuntu 系统源、ROS 2 APT 源、rosdep 的 rosdistro 索引和 rosdep 源列表镜像是四套独立配置：

- Ubuntu 源负责基础系统命令和开发工具；
- ROS APT 源负责 ROS 2 软件包；
- rosdep 索引源负责 ROS 发行版索引；
- rosdep 源列表镜像负责 `rosdep update` 实际读取的 YAML 文件。

仓库默认配置位于 `.env.example`。需要针对本机修改时复制一份：

```bash
cp .env.example .env
```

然后修改以下配置：

```dotenv
SOURCE_MODE=mirror
UBUNTU_MIRROR_AMD64=https://mirrors.tuna.tsinghua.edu.cn/ubuntu
UBUNTU_MIRROR_ARM64=https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports
ROS_APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu
ROSDISTRO_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/rosdistro/index-v4.yaml
ROSDEP_SOURCE_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/github-raw/ros/rosdistro/master
```

容器会根据 `dpkg --print-architecture` 选择 Ubuntu amd64 或 arm64 源。Apple Silicon 原生构建通常使用 `linux/arm64`，因此会使用 Ubuntu Ports；如果指定 `linux/amd64`，则使用 amd64 源。

需要切换到官方源时直接执行：

```bash
make build-official
```

修改源配置后需要重新构建镜像；已经构建好的镜像不会自动更新。

`FROM ros:jazzy-ros-base` 的基础镜像下载属于 Docker 镜像源，不受 APT 源配置影响。Docker Hub 加速应在 Docker Desktop 或 Colima 中单独配置。

## 基础镜像边界

基础镜像包含：

- 常用 Shell、编辑器、文件、压缩、网络、进程和 JSON 工具；
- Git、CMake、Ninja、pkg-config、GDB 和基础编译工具；
- Python、虚拟环境、rosdep、colcon、vcstool 和 ROS 开发工具；
- ROS 2 Jazzy 基础运行环境。

基础镜像不包含：

- Gazebo、RViz、TurtleBot3、Nav2 和 SLAM；
- `turtlesim`、`demo_nodes_cpp`、`demo_nodes_py`；
- CycloneDDS、noVNC、X11、GPU 或宿主机设备配置；
- 任何 ROS 学习代码或应用工作区。

这些内容应在后续独立的派生镜像或下游项目中维护，避免污染通用基础环境。

## 维护方式

修改环境定义后，先运行：

```bash
make test
make build
make smoke
```

基础服务通过 Docker Compose 管理，Make 是推荐的日常入口。后续增加仿真或机器人环境时，应在基础镜像之上增加独立服务或派生镜像，不把仿真依赖反向加入基础层。

参考：

- [ROS 2 Jazzy Ubuntu 安装说明](https://docs.ros.org/en/jazzy/Installation/Alternatives/Ubuntu-Install-Binary.html)
- [清华 ROS 2 镜像](https://mirrors.tuna.tsinghua.edu.cn/help/ros2/)
- [清华 rosdistro 镜像](https://mirrors.tuna.tsinghua.edu.cn/help/rosdistro/)
- [清华 Ubuntu Ports 镜像](https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu-ports/)
