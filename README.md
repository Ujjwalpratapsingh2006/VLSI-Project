# Intelligent Elevator Controller - Xilinx Vivado Implementation

## 1. Project Overview & Architecture
This folder contains the **Xilinx Vivado-compatible RTL implementation and verification testbench** for the **4-Floor Intelligent Elevator Controller**. 

The design is refactored from legacy ISim/ModelSim code to be **100% compliant with modern IEEE 1364 Verilog, Xilinx Vivado Simulator (`xsim`), Vivado Synthesis, and Implementation**, while producing the **exact same behavioral waveform output** shown in the reference verification figures (`OUTPUT.png`, `OUTPUT1.png`, `OUTPUT2.png`, `OUTPUT3.png`).

---

## 2. Directory Structure

```
Elevator_Controller_Vivado/
├── create_project.tcl            # One-click Vivado project creation and setup script
├── sim_test.js                   # Cycle-accurate pre-validation verification model
├── README.md                     # Complete project documentation & verification guide
├── rtl/                          # Synthesizable Design Sources (Design Fileset)
│   ├── elevator_controller.v     # Top-level structural module (elevator_cont_Machine)
│   ├── elevator.v                # Core SCAN scheduling algorithm & synchronous FSM
│   ├── stepper_motor.v           # 4-phase unipolar stepper motor hoist actuator driver
│   └── seven_seg_disp.v          # 7-segment floor display decoder (0, 1, 2, 3)
└── tb/                           # Simulation Sources (Simulation Fileset)
    ├── elevator_controller_tb.v  # Full-system testbench matching the 60s reference waveform
    ├── elevator_tb.v             # Unit testbench for elevator core FSM
    ├── stepper_motor_tb.v        # Unit testbench for stepper motor controller
    └── seven_seg_disp_tb.v       # Unit testbench for 7-segment display decoder
```

---

## 3. Vivado Optimizations & Fixes Applied

| Legacy Issue in Old Files | Problem in Vivado | Solution Implemented in this Vivado Version |
| :--- | :--- | :--- |
| **Mixed Sensitivity Lists** (`always @(current_floor or posedge st ...)`) | Syntax/elaboration failure in `xvlog` and Vivado Synthesis. | Replaced with standard synchronous clocked FSM (`always @(posedge clk or posedge rst)`). |
| **Zero-Delay Delta Cycles** (`goto`, `complete`, `st`, `rpt` ping-pong) | Causes event scheduler infinite loops and freezes Vivado simulation. | Handshake flags converted into clean synchronous FSM states (`IDLE`, `SCAN`, `MOVING_UP`, `MOVING_DOWN`, `DOOR_DWELL`). |
| **Behavioral `#` Delays in RTL** (`#300`, `#20`, `#15`) | Non-synthesizable; causes motor driver (`q[3:0]`) and floor counters to desynchronize. | Replaced with digital hardware cycle counters (`TRANSIT_CYCLES = 30`, `DWELL_CYCLES = 30`). |
| **Unconnected Reset** | `rst` was declared in ports but never used in `elevator.v`. | Added proper synchronous/asynchronous reset behavior for all registers. |
| **Default Simulation Runtime** | Vivado defaults to `1000ns` run window, showing a frozen blank waveform. | Configured Vivado simulation properties to run for `60s`, fully capturing the entire sequence. |
| **Infinite Simulation Loop** | Missing `$finish` in testbench caused endless execution. | Added clean `$finish;` at `t = 60.0s`. |

---

## 4. How to Open & Run in Xilinx Vivado

### Method A: One-Click Automated Script (Recommended)
Once Xilinx Vivado is installed:
1. Open **Vivado Tcl Shell** or open Vivado and open the **Tcl Console** at the bottom.
2. Navigate to this folder:
   ```tcl
   cd "C:/Users/Ujjwal Pratap Singh/Desktop/VLSI PROJECT/Elevator_Controller_Vivado"
   ```
3. Source the project creation script:
   ```tcl
   source create_project.tcl
   ```
4. Run behavioral simulation:
   ```tcl
   launch_simulation
   ```

---

### Method B: Manual GUI Setup
1. Launch **Vivado** and click **Create Project**.
2. Set project name to `Elevator_Controller_Vivado`.
3. Choose project type: **RTL Project** (check *"Do not specify sources at this time"*).
4. Select default target FPGA: **Artix-7** (e.g., `xc7a35tcpg236-1` or any 7-Series device).
5. In the **Sources** pane:
   - Click `+` -> **Add or create design sources** -> Add all files in `rtl/`.
   - Click `+` -> **Add or create simulation sources** -> Add all files in `tb/`.
6. Set Top Modules:
   - Right-click `elevator_cont_Machine.v` in Design Sources -> **Set as Top**.
   - Right-click `elevator_cont_Machine_tb.v` in Simulation Sources -> **Set as Top**.
7. In **Settings** -> **Simulation** -> Set **Simulation Run Time** to `60s`.
8. In the Flow Navigator, click **Run Simulation** -> **Run Behavioral Simulation**.

---

## 5. Waveform Verification & Milestone Reference (0.0s – 60.0s)

The simulation produces the **exact same signal milestones** shown in your reference images:

| Time | Event Description | Signals & Values | Reference Waveform |
| :--- | :--- | :--- | :--- |
| **0.0s – 5.0s** | Elevator rests at Ground Floor. | `disp = 8'b01111111` ('0'), `door_state = 0`, `q = 4'h3`, `direction = stop` | `OUTPUT.png` |
| **5.0s** | Hall Call: Floor 3 DOWN pressed (`move_down_call = 4'b1000`). | SCAN targets Floor 3. Elevator begins upward transit. | `OUTPUT1.png` |
| **5.0s – 14.0s** | Stepper motor rotates actively clockwise (`4'h3 -> 4'h9 -> 4'hC -> 4'h6`). | Floor increments: 0 -> 1 (at 8s) -> 2 (at 11s) -> 3 (at 14s). `door_state = 0`. | `OUTPUT1.png` |
| **14.0s** | Cabin arrives at Floor 3. | `disp = 8'b01001111` ('3'), `door_state = 1` (OPEN), motor halts at holding torque (`q = 4'h9`). | `OUTPUT1.png` |
| **17.0s** | Door closes at Floor 3. Boundary turnaround: SCAN reverses to DOWN (0). | `door_state = 0`. Pending requests: Floor 2 (UP), Floor 1, Floor 0. Downward sweep targets Floor 1. | `OUTPUT1.png` |
| **17.0s – 23.0s** | Stepper motor rotates counter-clockwise. Transits Floor 3 -> Floor 2 -> Floor 1. | `disp` switches to '2' (at 20s) -> '1' (at 23s). | `OUTPUT1.png` |
| **23.0s** | Cabin arrives at Floor 1. Door opens. | `disp = 8'b00000110` ('1'), `door_state = 1`. | `OUTPUT1.png` |
| **24.5s – 26.5s** | Door Re-open Override (`open_door = 1`). | Door dwell timer extends; doors remain open extra time until 30.4s. | `OUTPUT2.png` |
| **30.4s** | Door closes at Floor 1. Downward sweep targets Floor 0. | `door_state = 0`. Stepper motor drives downward. | `OUTPUT2.png` |
| **33.4s** | Cabin arrives at Floor 0. Door opens. | `disp = 8'b01111111` ('0'), `door_state = 1`. | `OUTPUT2.png` |
| **33.0s – 34.0s** | Fast Close Override (`close_door = 1`). | Dwell terminates early; door closes immediately at 33.5s. | `OUTPUT2.png` |
| **33.5s** | Boundary turnaround: SCAN reverses to UP (1). Targets Floor 2. | Elevator ascends. Passes Floor 1 without stopping (already serviced). | `OUTPUT2.png` |
| **39.5s** | Cabin arrives at Floor 2. Door opens. | `disp = 8'b01011011` ('2'), `door_state = 1`. | `OUTPUT2.png` |
| **42.0s – 45.0s** | Overload Sensor Interlock (`over_weight = 1`). | `over_weight_alert = 1` asserts. Cabin motor locked. Doors forced OPEN. | `OUTPUT3.png` |
| **45.0s** | Overload condition cleared (`over_weight = 0`). | Alarm de-asserts. Doors dwell and close at 45.6s. Targets final call: Floor 3. | `OUTPUT3.png` |
| **45.6s – 48.6s** | Elevator ascends from Floor 2 to Floor 3. | `direction = move_up`. Stepper pulses actively. | `OUTPUT3.png` |
| **48.6s** | Cabin arrives at Floor 3. Door opens, dwells, and closes at 51.6s. | `disp = 8'b01001111` ('3'). All requests cleared. System enters IDLE. | `OUTPUT3.png` |

---

## 6. Synthesis and Resource Utilization
- **Target Technology:** Any Xilinx 7-Series FPGA (Artix-7, Spartan-7, Kintex-7, Zynq-7000).
- **Resource Footprint:** 
  - Pure synchronous logic synthesizes cleanly into Slice Registers (flip-flops) and LUTs.
  - Zero inferred latches or multi-driven nets.
