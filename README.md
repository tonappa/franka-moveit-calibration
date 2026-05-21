# Franka Panda + qbSoftHand — ROS Noetic (Docker)

Workspace for controlling the Franka Panda robot with MoveIt and qbSoftHand as end effector, running on ROS Noetic inside Docker.

> **Note:** requires a PC with an NVIDIA GPU.

---

## Requirements

- Linux with NVIDIA drivers installed (`nvidia-smi` must work)
- Docker Engine and Docker Compose installed
- Active X11 graphical session on the host (`DISPLAY=:0`)
- User in the `audio` and `video` groups

---

## 1. Clone the repository

```bash
git clone --recurse-submodules -b softhand git@github.com:tonappa/franka.git
cd franka
```

The `--recurse-submodules` flag automatically downloads the external packages:
- `src/utils/qbdevice-ros` (including its nested submodules)
- `src/utils/qbhand-ros`

If you already cloned without `--recurse-submodules`, fetch the submodules with:

```bash
git submodule update --init --recursive
```

---

## 2. Build the Docker image

```bash
./run_docker.sh build
```

This installs ROS Noetic with Franka, MoveIt, and controller packages.

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
catkin build
source devel/setup.bash
```

---

## 5. Stop the container

```bash
./run_docker.sh down
```

---

## 6. One-time setup — serial port permissions

On the **host** machine (not inside the container), add your user to the `dialout` group to access the USB-RS485 converter:

```bash
sudo gpasswd -a $USER dialout
```

Then logout and log back in (or reboot).

---

## 7. qbSoftHand usage

The qbSoftHand communicates via USB-RS485 converter connected to the workstation PC. Make sure the converter is plugged in before starting the container.

### Step 1 — Communication Handler (terminal 1)

Must always be started first. It scans serial ports and manages communication with the device:

```bash
roslaunch qb_device_driver communication_handler.launch
```

Expected output if the hand is connected:
```
[CommunicationHandler] handles [/dev/ttyUSB0]
[CommunicationHandler] has found [1] device connected
```

### Step 2 — Control node (terminal 2)

```bash
roslaunch qb_hand_control control.launch \
  standalone:=false \
  activate_on_initialization:=true \
  device_id:=1 \
  use_without_robot:=true
```

> `use_without_robot:=true` means the hand node does **not** publish its own robot description — the full robot description (Franka + SoftHand) is handled separately by your launch file.

### Control modes

**GUI control** — interactive slider, useful for initial testing:

```bash
roslaunch qb_hand_control control.launch \
  standalone:=false \
  activate_on_initialization:=true \
  device_id:=1 \
  use_without_robot:=true \
  use_controller_gui:=true
```

An rqt panel opens with a slider from `0` (fully open) to `1` (fully closed).

---

**Topic control** — send commands from terminal or code (terminal 3):

```bash
rostopic pub -1 /qbhand1/control/qbhand1_synergy_trajectory_controller/command \
  trajectory_msgs/JointTrajectory "
header: {seq: 0, stamp: {secs: 0, nsecs: 0}, frame_id: ''}
joint_names: ['qbhand1_synergy_joint']
points:
- positions: [1]
  velocities: [0]
  accelerations: [0]
  effort: [0]
  time_from_start: {secs: 1, nsecs: 0}"
```

| `positions` value | Hand state |
|---|---|
| `[0]` | fully open |
| `[0.5]` | half closed |
| `[1]` | fully closed |

`time_from_start` controls speed: larger value = slower motion.

---

**Waypoint control** — automated cyclic trajectory:

```bash
roslaunch qb_hand_control control.launch \
  standalone:=false \
  device_id:=1 \
  use_without_robot:=true \
  use_waypoints:=true \
  robot_name:=qbhand1 \
  robot_package:=qb_hand_control
```

The trajectory is defined in `qb_hand_control/config/qbhand1_waypoints.yaml`.

### Manual motor activation

If `activate_on_initialization:=false`, activate the motor manually when ready:

```bash
rosservice call /communication_handler/activate_motors "{id: 1, max_repeats: 0}"
```

---

## 8. Franka + qbSoftHand integrated pipeline (MoveIt)

Recommended way to bring up the **real** Franka with the qbSoftHand mounted on the
flange and plan/execute with MoveIt. Two terminals are enough.

**Pre-conditions**: Franka powered on, FCI active from Desk
(`https://<robot_ip>/desk`), brakes released, qbSoftHand connected via USB.

### Terminal 1 — robot bringup (Franka + hand + optional RealSense)

```bash
roslaunch franka_softhand_bringup franka_softhand.launch \
    robot_ip:=<FRANKA_IP> \
    device_id:=1
```

Defaults already set inside the launch:
- `standalone:=true` — starts the qb communication handler
- `activate_on_initialization:=true` — qbSoftHand motors armed at startup
- `set_commands_async:=true` — required for the qb HW write loop at 1 ms
- `realtime_config:=ignore` — avoids `RealtimeException` on non-PREEMPT_RT kernels.
  If you have RT permissions/kernel set, override with `realtime_config:=enforce`.

Useful overrides: `arm_id:=panda`, `use_specific_serial_port:=true serial_port_name:=/dev/ttyUSB0`.

The base bringup does **not** start the RealSense camera. For perception or
hand-eye calibration, use the dedicated launches under `franka_softhand_handeye`
(see workflow 9).

### Terminal 2 — MoveIt (controllers + move_group + RViz)

```bash
roslaunch franka_softhand_bringup franka_softhand_moveit.launch
```

Spawns `position_joint_trajectory_controller` for the arm (rigid, libfranka motion
generator), wires MoveIt to the already-running
`/qbhand/control/qbhand_synergy_trajectory_controller` for the hand, then starts
`move_group` and RViz.

Optional args: `use_rviz:=false`, `pipeline:=chomp`.

---

## Notes — manual hand commands

The hand controller is `qbhand_synergy_trajectory_controller` in the `/qbhand/control/`
namespace. Closure value range: **`0` = fully open, `1` = fully closed**.

**Close:**
```bash
rostopic pub -1 /qbhand/control/qbhand_synergy_trajectory_controller/command \
  trajectory_msgs/JointTrajectory "{
    joint_names: ['qbhand_synergy_joint'],
    points: [{positions: [1.0], time_from_start: {secs: 2}}]
  }"
```

**Open:**
```bash
rostopic pub -1 /qbhand/control/qbhand_synergy_trajectory_controller/command \
  trajectory_msgs/JointTrajectory "{
    joint_names: ['qbhand_synergy_joint'],
    points: [{positions: [0.0], time_from_start: {secs: 2}}]
  }"
```

`time_from_start` controls the duration (larger = slower).

GUI alternative (slider):
```bash
rosrun rqt_joint_trajectory_controller rqt_joint_trajectory_controller
# select controller_manager: /qbhand/control, controller: qbhand_synergy_trajectory_controller
```

> Do not mix topic publishing and the action server on the same device.

---

## Notes — recovering from a Franka reflex

If MoveIt aborts with `motion aborted by reflex! ["cartesian_reflex"]` or any
subsequent command is rejected with
`command not possible in the current mode ("Reflex")`, the robot is in error
state and must be re-armed:

```bash
rostopic pub -1 /franka_control/error_recovery/goal \
  franka_msgs/ErrorRecoveryActionGoal "{}"
```

After recovery the arm will re-engage and accept new motion commands.

**Avoiding reflexes:**
- In RViz set `Velocity Scaling` and `Acceleration Scaling` to `0.1–0.2` for
  conservative motions (the SoftHand on the flange adds inertia, making the default
  `franka_control_node.yaml` cartesian thresholds easy to trip).
- For higher speeds, raise the cartesian/torque collision thresholds at runtime:

  ```bash
  rosservice call /franka_control/set_force_torque_collision_behavior "{
    lower_torque_thresholds_nominal: [40,40,36,36,32,28,24],
    upper_torque_thresholds_nominal: [40,40,36,36,32,28,24],
    lower_force_thresholds_nominal:  [40,40,40,50,50,50],
    upper_force_thresholds_nominal:  [40,40,40,50,50,50]
  }"
  ```

---

## 9. Hand-eye calibration (eye-to-hand, RealSense D435i)

Eye-to-hand setup: RealSense fixed in the world, ArUco board mounted on the
robot flange. Uses `moveit_calibration` (submodule under
`src/utils/moveit_calibration`, tracked on `master`).

The Python dependencies of the default solver (`handeye`, `criutils`, `baldor`)
are installed from apt in the Docker image
(`ros-noetic-handeye/criutils/baldor`) — no submodule branch switch is required.
Build the workspace inside the container:

```bash
catkin_make
source devel/setup.bash
```

### Pre-conditions

- Workflow 8 pre-conditions (Franka FCI, qbSoftHand connected).
- RealSense D435i physically mounted at a fixed position in the world (not on
  the EE).
- ArUco board printed and rigidly attached to `panda_link8`.
- `franka_softhand_handeye/config/camera_pose.yaml` contains a **reasonable
  initial guess** for the camera pose (not zero — the solver converges much
  better with a guess close to the truth).

### Launch (single terminal)

```bash
roslaunch franka_softhand_handeye handeye_calibration.launch robot_ip:=<FRANKA_IP>
```

This brings up everything in one shot: Franka + qbSoftHand bringup, the
handeye URDF wrapper (which adds the RealSense at the guess pose from
`camera_pose.yaml`), MoveIt (`move_group` + planning scene), RealSense D435i
node, and RViz.

### RViz HandEyeCalibration panel

`Panels → Add New Panel → HandEyeCalibration`.

**Target tab** — must match the printed board:
- *Target type*: `HandEyeTarget/ArucoGridBoard`
- *Marker dictionary*: `DICT_4X4_50` (try `_100` / `_250` if detection fails)
- *Markers, X* = `2`, *Markers, Y* = `2`
- *Marker size (m)*: `0.018` (single black side, in metres — adjust to the
  actual print)
- *Marker separation (m)*: `0.004` (white gap between two markers)
- *Marker border bits*: `1`
- *First marker ID*: `0`
- *Image topic*: `/camera/color/image_raw`
- *Camera info topic*: `/camera/color/camera_info`

A green overlay appears on the board both in the panel preview and on the
`/handeye_calibration/target_detection` image topic. If "Target detection
failed": dictionary / size / separation wrong, marker not fully in frame, or
poor lighting / blur.

**Context tab**:
- *Sensor configuration*: **Eye-to-hand**
- *Sensor frame*: `camera_color_optical_frame`
- *Object frame*: `handeye_target` (appears only after the target is detected
  at least once)
- *End-effector frame*: `panda_link8`
- *Robot base frame*: `panda_link0`

**Calibrate tab**:
- *Calibration solver*: **`ParkBryan1994`** (do **not** use `Daniilidis1999`
  — it returns complex eigenvalues with few or poorly-varied samples,
  failing with `TypeError: can't convert complex to ...`).
- Acquire **≥15 samples** with **varied orientations** (≥30° on different
  axes — pitch, roll, yaw of the EE).
- Wait 1–2 s after each motion stops before clicking `Take sample` (libfranka
  residual vibrations affect the pose).
- For eye-to-hand you move the marker (= the robot); the camera is fixed.
- Click `Solve`. Sanity-check by re-solving with `TsaiLenz1989` — the two
  results should agree to a few millimetres / one degree.

### Save and apply the calibration

1. `Save camera pose` → save into
   `franka_softhand_handeye/launch/camera_pose.launch`. It contains a
   `static_transform_publisher` with the calibrated `world → camera_link`
   transform (xyz + quaternion, plus an `rpy=...` comment).
2. To use it in your perception pipeline, include it from a top-level launch:
   ```xml
   <include file="$(find franka_softhand_handeye)/launch/camera_pose.launch"/>
   ```
3. Optional: copy `xyz` and `rpy` from the `.launch` comment into
   `franka_softhand_handeye/config/camera_pose.yaml` so the URDF guess used in
   subsequent calibrations starts from the calibrated value.

**Validation**: in RViz add a `TF` display and a `RobotModel`. The frame
`camera_color_optical_frame` must sit physically where the real RealSense is
mounted; clicking on the board in the world, `handeye_target` must appear on
the actual marker surface (within 1–2 cm).

### Common runtime issues

- **`Controller Spawner couldn't find the expected controller_manager`** and
  `franka_control` exposes no `/controller_manager/*` services → `franka_control`
  is alive but blocked at init. Causes, in order: wrong `robot_ip`, brakes
  closed, FCI not active on Franka Desk, or robot in error state. Fix on Desk
  (`https://<robot_ip>/desk`), then relaunch.
- **RViz shows the robot in the "all zero" pose** while the real robot is in
  another configuration → that is the *Planning Request* ghost in MotionPlanning,
  not the live state. Update Start State → `<current>`, or add a separate
  `RobotModel` display that follows live TF.
- **`TypeError: can't convert complex to ...`** from the solver → switch the
  Calibration solver away from `Daniilidis1999` (see above) and/or add more
  samples with wider orientation diversity.
- **RealSense `control_transfer` libusb warnings** → harmless USB hiccups
  typical of RealSense inside Docker; ignorable unless images stop arriving.

---

## Project structure

```
franka/
├── docker/
│   ├── Dockerfile          # ROS Noetic image with Franka + MoveIt
│   ├── entrypoint.sh       # Automatic ROS environment sourcing
│   └── requirements.txt    # Python dependencies (optional)
├── src/
│   └── utils/
│       ├── qbdevice-ros/   # qbrobotics driver (submodule)
│       └── qbhand-ros/     # qbSoftHand packages (submodule)
├── docker-compose.yaml
└── run_docker.sh
```

---

## Credits

- [Do Won Park](https://github.com/tonappa) — Istituto Italiano di Tecnologia
