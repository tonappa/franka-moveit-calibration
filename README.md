# franka-moveit-calibration

Eye-to-hand hand-eye calibration for Franka Panda with Intel RealSense D435i, running on ROS Noetic inside Docker.

The calibration result (`world → camera_link` transform) is saved as a `static_transform_publisher` launch file and can be copied into any other workspace that uses the camera with the Panda.

> **Note:** requires a PC with an NVIDIA GPU.

---

## Requirements

- Linux with NVIDIA drivers installed (`nvidia-smi` must work)
- Docker Engine and Docker Compose installed
- Active X11 graphical session on the host (`DISPLAY=:0`)
- User in the `video` group

---

## 1. Clone the repository

```bash
git clone --recurse-submodules git@github.com:tonappa/franka-moveit-calibration.git
cd franka-moveit-calibration
```

The `--recurse-submodules` flag downloads:
- `src/utils/moveit_calibration` — MoveIt hand-eye calibration plugin
- `src/utils/franka_ros` — Franka ROS stack (Noetic branch, `noetic-devel`)

If you already cloned without it:

```bash
git submodule update --init --recursive
```

### One-time post-clone edit

Open `src/utils/franka_ros/franka_control/config/franka_control_node.yaml` and make sure:

```yaml
realtime_config: ignore
```

This is already handled in the launch file (`<param name="realtime_config" value="ignore"/>`), so no manual edit is required.

---

## 2. Build the Docker image

```bash
./run_docker.sh build
```

Installs ROS Noetic with Franka, MoveIt, `panda_moveit_config`, `moveit_calibration`, and RealSense packages.

---

## 3. Run the container

```bash
./run_docker.sh run
```

The container mounts the workspace at `/home/ros/franka`, forwards the GUI via X11, and enables the NVIDIA GPU.

---

## 4. Build the catkin workspace

Inside the container:

```bash
catkin_make
source devel/setup.bash
```

---

## 5. Stop the container

```bash
./run_docker.sh down
```

---

## 6. Hand-eye calibration (eye-to-hand, RealSense D435i)

Eye-to-hand setup: RealSense D435i fixed in the world, ArUco board mounted on `panda_link8`.

> **Note:** the gripper is intentionally disabled for the calibration (`hand:=false` in the URDF xacro and `load_gripper:=false` passed to `move_group.launch`). It is not needed to obtain the `world → camera_link` transform, and removing it avoids SRDF/URDF mismatches. If your downstream project needs the hand, re-enable both flags after calibration.

**Pre-conditions**:
- Franka powered on, FCI active from Desk (`https://<robot_ip>/desk`), brakes released.
- RealSense D435i physically mounted at a fixed position in the world (not on the EE).
- ArUco board printed and rigidly attached to `panda_link8`.
- `src/franka_handeye_calibration/config/camera_pose.yaml` contains a reasonable initial guess for the camera pose (not zero — the solver converges better with a guess close to the truth).

### Launch (single terminal)

```bash
roslaunch franka_handeye_calibration handeye_calibration.launch robot_ip:=<FRANKA_IP>
```

This brings up everything in one shot: `franka_control`, `position_joint_trajectory_controller`, `move_group` (from `panda_moveit_config`), RealSense D435i node, and RViz.

### ArUco board

The board used is `aruco.png` in the repo root. Print it and mount it rigidly on `panda_link8`.

Board parameters (used both to generate the image and to configure the RViz panel):

| Parameter | Value |
|---|---|
| Dictionary | `DICT_4X4_50` |
| Markers X | 2 |
| Markers Y | 2 |
| Marker size (px) | 180 |
| Marker separation (px) | 40 — ratio 18:4 (4.5:1) |
| Marker border (bits) | 1 |
| Measured marker size (m) | **0.018** (1.8 cm each) |
| Measured separation (m) | **0.004** (0.4 cm gap) |

### RViz HandEyeCalibration panel

`Panels → Add New Panel → HandEyeCalibration`.

**Target tab**:
- *Target type*: `HandEyeTarget/ArucoGridBoard`
- *Marker dictionary*: `DICT_4X4_50`
- *Markers, X* = `2`, *Markers, Y* = `2`
- *Marker size (m)*: `0.018`
- *Marker separation (m)*: `0.004`
- *Marker border bits*: `1`
- *First marker ID*: `0`
- *Image topic*: `/camera/color/image_raw`
- *Camera info topic*: `/camera/color/camera_info`

A green overlay appears on the board in the panel preview. If "Target detection failed": dictionary / size / separation wrong, marker not fully in frame, or poor lighting / blur.

**Context tab**:
- *Sensor configuration*: choose **Eye-to-hand** or **Eye-in-hand** depending on your setup.
- Select the desired frames for your configuration:
  - *Sensor frame*: e.g. `camera_color_optical_frame`
  - *Object frame*: `handeye_target` (appears after the target is detected at least once)
  - *End-effector frame*: e.g. `panda_link8` (or `panda_hand` for eye-in-hand)
  - *Robot base frame*: e.g. `panda_link0`

**Calibrate tab**:
- *Calibration solver*: **`crigroup/Daniilidis1999`**.
- Acquire **>15 samples** by moving the robot to a variety of positions and orientations (wide angular spread on different axes — pitch, roll, yaw of the EE — gives a better solution).
- Wait 1–2 s after each motion stops before clicking `Take sample`.
- After collecting samples, click `Solve` to obtain the camera pose. Use this result as the **initial guess** in `src/franka_handeye_calibration/config/camera_pose.yaml` if you want to refine the calibration with a second run.

### Save and apply the calibration

1. Click `Save camera pose` and save it into `src/franka_handeye_calibration/launch/`.
   This produces a launch file containing a `static_transform_publisher` with the calibrated camera pose (xyz + quaternion).
2. In that folder you will find the calibrated camera pose, ready to be reused in any of your downstream projects that need the `world → camera_link` transform.

**Validation**: in RViz add a `TF` display and a `RobotModel`. The frame `camera_color_optical_frame` must sit physically where the real RealSense is mounted; `handeye_target` must appear on the actual marker surface (within 1–2 cm).

### Common runtime issues

- **`Controller Spawner couldn't find the expected controller_manager`** → `franka_control` is blocked at init. Causes: wrong `robot_ip`, brakes closed, FCI not active, robot in error state. Fix on Desk, then relaunch.
- **`TypeError: can't convert complex to ...`** from the solver → switch away from `Daniilidis1999` and/or add more samples with wider orientation diversity.
- **RealSense `control_transfer` libusb warnings** → harmless USB hiccups inside Docker; ignorable unless images stop arriving. Do **not** use `initial_reset:=true`.

---

## Recovering from a Franka reflex

```bash
rostopic pub -1 /franka_control/error_recovery/goal \
  franka_msgs/ErrorRecoveryActionGoal "{}"
```

---

## Project structure

```
franka-moveit-calibration/
├── docker/
│   ├── Dockerfile          # ROS Noetic image with Franka + MoveIt + RealSense
│   ├── entrypoint.sh
│   └── requirements.txt
├── src/
│   ├── franka_handeye_calibration/
│   │   ├── config/
│   │   │   ├── camera_pose.yaml   # initial guess (edit before calibrating)
│   │   │   ├── saved_joints.yaml  # joint poses for sample collection
│   │   │   └── saved_samples.yaml # collected calibration samples
│   │   ├── launch/
│   │   │   ├── handeye_calibration.launch  # main entry point
│   │   │   └── camera_pose.launch          # saved calibration result (TF static)
│   │   └── urdf/
│   │       └── panda_handeye.urdf.xacro    # Panda + camera at guess pose
│   └── utils/
│       ├── franka_ros/          # submodule (noetic-devel)
│       └── moveit_calibration/  # submodule (master)
├── docker-compose.yaml
└── run_docker.sh
```

---

## Credits

- [Do Won Park](https://github.com/tonappa) — Istituto Italiano di Tecnologia
