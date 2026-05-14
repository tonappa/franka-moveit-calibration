#!/bin/bash
set -e

# source ROS environment
source /opt/ros/${ROS_DISTRO}/setup.bash

# dynamic workspace path
WORKSPACE_PATH="/home/ros/${WORKSPACE_NAME}"

# source workspace, if already compiled
if [ "$ROS_VERSION" = "1" ] && [ -f "${WORKSPACE_PATH}/devel/setup.bash" ]; then
    echo "Sourcing ROS 1 workspace: ${WORKSPACE_PATH}/devel/setup.bash"
    source "${WORKSPACE_PATH}/devel/setup.bash"
elif [ "$ROS_VERSION" = "2" ] && [ -f "${WORKSPACE_PATH}/install/setup.bash" ]; then
    echo "Sourcing ROS 2 workspace: ${WORKSPACE_PATH}/install/setup.bash"
    source "${WORKSPACE_PATH}/install/setup.bash"
fi

# --- Additional setup: update system and install dependencies ---
echo "Updating system and installing ROS dependencies..."

# Use sudo only if not root
SUDO_CMD=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO_CMD="sudo"
fi

# Safe apt and rosdep sequence
$SUDO_CMD apt update -y && \
$SUDO_CMD apt upgrade -y || echo "Apt update/upgrade failed, continuing..."

if command -v rosdep > /dev/null; then
    rosdep update || echo "rosdep update failed, continuing..."
    if [ -d "${WORKSPACE_PATH}/src" ]; then
        rosdep install --from-paths "${WORKSPACE_PATH}/src" --ignore-src -r -y || \
        echo "rosdep install encountered issues, continuing..."
    fi
else
    echo "rosdep not found, skipping rosdep steps."
fi

# --- Execute the user command (e.g., bash) ---
exec "$@"

