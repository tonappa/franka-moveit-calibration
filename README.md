# DOCKER COMPOSE TEMPLATE (Docker + GPU + GUI)

Docker compose template for ROS1 or ROS2 workspace.  
It features NVIDIA GPU acceleration, X11 GUI forwarding, audio device support, and VSCode integration.

*NOTE: only for PCs with NVIDIA GPU*
---

## Directory Structure & Key Files

- `run_docker.sh`: Script to build, run, and stop the Docker container - manages environment variables, X11 permissions, and hardware mappings.
- `docker-compose.yaml`: Defines the service, GPU devices, privileges, hardware mounts, environment variables, and volumes.
- `docker/Dockerfile`: Builds the ROS base image including Python dependencies such as MediaPipe and OpenCV; sets up user permissions.
- `.env`: Environment variables for customizing container name, display, workspace, etc.
- `docker/entrypoint.sh`: Entrypoint script that sources ROS setup and the workspace dynamically at container start.

---

## Requirements

- Linux host with NVIDIA drivers installed and working (`nvidia-smi` should detect your GPU).
- Docker Engine and Docker Compose installed.
- Active X11 graphical session on the host (typically `DISPLAY=:0`).
- User in the `audio` and `video` groups to access hardware devices.
- Permissions to mount devices for video, audio, and X11 forwarding.

---

## ROS Version Customization

- in `run_docker.sh` (*only there!*) change ros distro and version.

---

## Quickstart Guide

### 0. Worspace Preparation

Clone the repository in the desired directory
```bash
git clone git@github.com:tonappa/docker_compose_template.git
```

Change the name of the repository *docker_compose_template* with a desired one.

### 1. Build the Docker Image

```bash
./run_docker.sh build
```

### 2. Run the Container with GPU and GUI Support

On your host terminal:

```bash
export DISPLAY=:0 # Make sure this matches your active X session
xhost +local:docker # Grant X11 access to Docker containers
./run_docker.sh run
```

### 3. Stop and Clean Up the Container

```bash
./run_docker.sh down
```

---

## Hardware and GUI Integration

The container mounts important devices and volumes to access host hardware and forward GUI:

- GPU (NVIDIA) with full capabilities and runtime.
- Video capture devices (`/dev/video*`), DRM devices, and sound devices mapped.
- X11 socket (`/tmp/.X11-unix`) and `.Xauthority` for GUI forwarding.
- PulseAudio for sound forwarding.
- VSCode folders mounted for code editing and extensions.
- Workspace folder mounted for development.

---

## MediaPipe GPU Troubleshooting

- MediaPipe GPU relies on EGL/OpenGL ES accessible inside the container.
- If you see errors like `eglGetDisplay() returned error 0x3000`:
  - Verify `DISPLAY` inside the container matches the host's (e.g., `:0`).
  - Run `xhost +local:docker` *on the host* before starting the container.
  - Confirm you have an active graphical session with access inside the container (test with `xeyes` or `glxinfo`).
  - For headless setups, try running with a virtual display: `xvfb-run python3 mediapipe-gpu.py`.
  - Your setup supports automatic fallback to CPU if GPU delegate is unavailable.

---

## Environment Variables to Customize

Use `.env` and scripts to configure:

- Container and workspace names.
- Display number and X11 authority files.
- User IDs and group IDs for proper permission mapping.
- ROS distribution and version.
- VSCode paths and PulseAudio server.

---

## Audio & VSCode Integration

- PulseAudio is forwarded for audio input/output.
- VSCode settings and server extensions are persistently mounted to allow seamless code editing inside the container.

---

---

## Extending and Customizing

- Modify `.env` for personalized session names and hardware settings.
- Edit `docker-compose.yaml` to add extra device mounts or environment variables.
- *Expand `Dockerfile` to install additional ROS packages or other dependencies as needed.*

---

## Credits and Authors

- [Do Won Park](https://github.com/tonappa) (Istituto Italiano di Tecnologia).

---

## Support & Issues

Check X11 permissions and device visibility carefully before reporting issues.  
Open issues on your repository or ROS/Docker forums with detailed logs for assistance.

---

Enjoy developing your ROS hand teleoperation workspace with GPU acceleration and GUI support!


