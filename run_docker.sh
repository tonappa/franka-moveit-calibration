#!/bin/bash

#Author: Do Won Park
#Istututo Italiano di Tecnologia (IIT)
#Email: do.park@iit.it

# =================================================================== #
#          workspace config and build, run and stop docker            #
# =================================================================== #
# for gpu support
export XAUTH=/tmp/.docker.xauth
# Crea il file di autorizzazione (se non esiste) e gestisci i permessi
echo "Creazione del file di autorizzazione XAUTH in $XAUTH"
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

# Controlla che il file sia stato creato
if [ ! -f "$XAUTH" ]; then
    echo "ERRORE: il file XAUTH non è stato creato."
    exit 1
fi

echo "File XAUTH creato e configurato."
echo "------------------------------------------------"

# --- write HERE the ROS version ---
ROS_DISTRO="noetic"
ROS_VERSION="1"

# --- docker parameter (automatic) ---
# export workspace name
export WORKSPACE_NAME=$(basename "$PWD")
IMAGE_NAME="${WORKSPACE_NAME}_ws"
CONTAINER_NAME="${WORKSPACE_NAME}_container"

# =================================================================== #

# create directories if not exist
mkdir -p ./docker
mkdir -p ./src

# --- export variable from docker-compose ---

# UID/GID 
export MYUID=$(id -u)
export MYGID=$(id -g)

# ros variables
export ROS_DISTRO
export ROS_VERSION
export IMAGE_NAME

# GUI variables
export DISPLAY=$DISPLAY
export XAUTH=/tmp/.docker.xauth
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

# audio variables
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
export PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native

# variable for bash chrono
export BASH_HISTORY_PATH=~/.bash_history
touch $BASH_HISTORY_PATH # check if file exist, otherwise create it

# hardware variable (audio/video)
# note: ensure if user is in'audio' e 'video' group
export AUDIO_GID=$(getent group audio | cut -d: -f3)
export VIDEO_GID=$(getent group video | cut -d: -f3)

# vscode integration variables
export VSCODE_PATH=~/.vscode
export VSCODE_SERVER_PATH=~/.vscode-server

# function to show usage
usage() {
    echo "Uso: $0 [build|run|down]"
    echo "  build: build docker image."
    echo "  run:   run interactive container."
    echo "  down:  stop and remove container. remove docker-compose networks."
}

# control arguments passed to the script
case "$1" in
    build)
        echo "building docker image '$IMAGE_NAME' with ROS${ROS_VERSION} ${ROS_DISTRO}..."
        docker compose -f ./docker-compose.yaml build --no-cache
        ;;
    run)
        echo "run container '$CONTAINER_NAME'..."
        # allow connections to X server
        xhost +local:docker
        # run the container interactively with --rm to remove it after exit
        docker compose -f ./docker-compose.yaml run --rm --name ${CONTAINER_NAME} ros_dev
        ;;
    down)
        echo "stops and remove container..."
        docker compose -f ./docker-compose.yaml down
        ;;
    *)
        usage
        exit 1
        ;;
esac

exit 0
