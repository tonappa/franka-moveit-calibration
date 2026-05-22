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
- *Sensor configuration*: **Eye-to-hand**
- *Sensor frame*: `camera_color_optical_frame`
- *Object frame*: `handeye_target` (appears after the target is detected at least once)
- *End-effector frame*: `panda_link8`
- *Robot base frame*: `panda_link0`

**Calibrate tab**:
- *Calibration solver*: **`ParkBryan1994`** (do **not** use `Daniilidis1999` — it returns complex eigenvalues with few or poorly-varied samples).
- Acquire **≥15 samples** with **varied orientations** (≥30° on different axes — pitch, roll, yaw of the EE).
- Wait 1–2 s after each motion stops before clicking `Take sample`.
- Click `Solve`. Sanity-check by re-solving with `TsaiLenz1989` — the two results should agree to a few millimetres / one degree.

### Save and apply the calibration

1. `Save camera pose` → save into `src/franka_handeye_calibration/launch/camera_pose.launch`.
   It contains a `static_transform_publisher` with `world → camera_link` (xyz + quaternion).
2. To use the result in another workspace, copy the `args` values (xyz + quaternion) into that workspace's camera pose YAML.

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
