# recall arguments from docker-compose
ARG ROS_DISTRO

FROM ros:${ROS_DISTRO}-perception

# ================================== ARGS ================================== #
ARG ROS_DISTRO
ARG MYUID=1000
ARG MYGID=1000
ARG USER=ros
ARG WORKSPACE_NAME=ros_ws

# ================================ ENV variables ================================ #
ENV DEBIAN_FRONTEND=noninteractive

# ============================ install dependencies =========================== #

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    git \
    bash-completion \
    build-essential \
    cmake \
    python3-pip \
    python3-rosdep \
    libgl1-mesa-glx \
    libsm6 \
    libxext6 \
    ros-${ROS_DISTRO}-realsense2-* && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install --no-install-recommends -y \
    ros-${ROS_DISTRO}-franka-ros \
    ros-${ROS_DISTRO}-libfranka \
    ros-${ROS_DISTRO}-panda-moveit-config \
    ros-${ROS_DISTRO}-moveit \
    ros-${ROS_DISTRO}-ros-controllers \
    ros-${ROS_DISTRO}-joint-state-publisher \
    ros-${ROS_DISTRO}-rviz \
    ros-${ROS_DISTRO}-handeye \
    ros-${ROS_DISTRO}-criutils \
    ros-${ROS_DISTRO}-baldor && \
    rosdep update && \
    rm -rf /var/lib/apt/lists/*

# ============================= user creation (as ROOT) ============================ #

RUN OLD_USER=$(awk -v uid="$MYUID" -F ':' '$3==uid {print $1}' /etc/passwd) \
    && if [ -z "${OLD_USER}" ]; then \
    addgroup --gid ${MYGID} ${USER} \
    && adduser --gecos "ROS User" --disabled-password --uid ${MYUID} --gid ${MYGID} ${USER} \
    && usermod -a -G dialout,video,sudo ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER}; \
    else \
    usermod -l ${USER} ${OLD_USER} \
    && usermod -d /home/${USER} -m ${USER} \
    && groupmod -g ${MYGID} ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER}; \
    fi

# =============================== assign to ros user ============================== #

USER ${USER}
ENV HOME=/home/${USER}

# ================================  workspace config (as USER) ================================ #

WORKDIR /home/${USER}/${WORKSPACE_NAME}
RUN mkdir -p ./src

# ==================================== Entrypoint (as USER) ==================================== #

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sudo chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
