// ==============================================================================
// Cycle-Accurate Validation Script for Vivado Elevator Controller (with Edge Detection)
// ==============================================================================

const CLK_PERIOD = 0.1;

let clk = 0;
let time_s = 0.0;

// Inputs
let move_up_call = 0, move_down_call = 0, req_floor = 0;
let move_up_d = 0, move_down_d = 0, req_floor_d = 0;
let open_door = 0, close_door = 0, over_weight = 0, rst = 0;

// State Registers
let current_floor = 0;
let next_floor = 0;
let direction = 3; // 1=UP, 2=DOWN, 3=STOP
let door_state = 0;
let over_weight_alert = 0;
let scan_direction = 1; // 1 = UP, 0 = DOWN
let state = "IDLE";
let timer = 0;
let stepper_state = 0;
let q = 0x3;
let disp = 0x7F;

let up_call_reg = [0,0,0,0];
let down_call_reg = [0,0,0,0];
let req_floor_reg = [0,0,0,0];

function active_req_count() {
    let count = 0;
    for(let i=0; i<4; i++) {
        if(up_call_reg[i]) count++;
        if(down_call_reg[i]) count++;
        if(req_floor_reg[i]) count++;
    }
    return count;
}

function evaluate_scan(cur, dir) {
    let found = false, tgt = cur, new_dir = dir;

    if (dir === 1) { // UPWARD
        for (let idx = 0; idx <= 3; idx++) {
            if (!found && idx >= cur && (up_call_reg[idx] || req_floor_reg[idx])) {
                tgt = idx;
                new_dir = (idx === 3) ? 0 : 1;
                found = true;
            }
        }
        if (!found) {
            for (let idx = 3; idx >= 0; idx--) {
                if (!found && (down_call_reg[idx] || req_floor_reg[idx])) {
                    tgt = idx;
                    new_dir = (idx === 0) ? 1 : 0;
                    found = true;
                }
            }
        }
        if (!found) {
            for (let idx = 0; idx <= 3; idx++) {
                if (!found && (up_call_reg[idx] || req_floor_reg[idx])) {
                    tgt = idx;
                    new_dir = 1;
                    found = true;
                }
            }
        }
    } else { // DOWNWARD
        for (let idx = 3; idx >= 0; idx--) {
            if (!found && idx <= cur && (down_call_reg[idx] || req_floor_reg[idx])) {
                tgt = idx;
                new_dir = (idx === 0) ? 1 : 0;
                found = true;
            }
        }
        if (!found) {
            for (let idx = 0; idx <= 3; idx++) {
                if (!found && (up_call_reg[idx] || req_floor_reg[idx])) {
                    tgt = idx;
                    new_dir = (idx === 3) ? 0 : 1;
                    found = true;
                }
            }
        }
        if (!found) {
            for (let idx = 3; idx >= 0; idx--) {
                if (!found && (down_call_reg[idx] || req_floor_reg[idx])) {
                    tgt = idx;
                    new_dir = 0;
                    found = true;
                }
            }
        }
    }
    return { found, new_dir, tgt };
}

function update_disp() {
    switch(current_floor) {
        case 0: disp = 0x7F; break;
        case 1: disp = 0x06; break;
        case 2: disp = 0x5B; break;
        case 3: disp = 0x4F; break;
    }
}

function update_stepper() {
    if (direction === 1 || direction === 2) {
        switch(stepper_state) {
            case 0: q = (direction === 1) ? 0x3 : 0x6; break;
            case 1: q = (direction === 1) ? 0x9 : 0xC; break;
            case 2: q = (direction === 1) ? 0xC : 0x9; break;
            case 3: q = (direction === 1) ? 0x6 : 0x3; break;
        }
        stepper_state = (stepper_state + 1) % 4;
    }
}

const milestone_log = [];

function clock_tick() {
    time_s = +(time_s + CLK_PERIOD).toFixed(2);

    // Testbench Stimulus timing
    if (time_s >= 0.2 && time_s < 0.25) rst = 0;
    if (time_s >= 5.0) move_down_call = 0x8; // Floor 3
    if (time_s >= 6.0) move_up_call = 0x4;   // Floor 2
    if (time_s >= 10.0) req_floor |= 0x2;    // Floor 1
    if (time_s >= 10.5) req_floor |= 0x1;    // Floor 0

    if (time_s >= 24.5 && time_s <= 26.5) open_door = 1;
    else open_door = 0;

    if (time_s >= 33.0 && time_s <= 34.0) close_door = 1;
    else close_door = 0;

    if (time_s >= 34.5) req_floor |= 0x8;    // Floor 3
    if (time_s >= 42.0 && time_s <= 45.0) over_weight = 1;
    else over_weight = 0;

    // Edge Detection for button latching
    let move_up_edge = move_up_call & ~move_up_d;
    let move_down_edge = move_down_call & ~move_down_d;
    let req_floor_edge = req_floor & ~req_floor_d;

    move_up_d = move_up_call;
    move_down_d = move_down_call;
    req_floor_d = req_floor;

    for (let i = 0; i < 4; i++) {
        if ((move_up_edge >> i) & 1) up_call_reg[i] = 1;
        if ((move_down_edge >> i) & 1) down_call_reg[i] = 1;
        if ((req_floor_edge >> i) & 1) req_floor_reg[i] = 1;
    }

    // Overweight Interlock
    if (over_weight) {
        over_weight_alert = 1;
        direction = 3;
        door_state = 1;
        update_disp();
        return;
    } else {
        over_weight_alert = 0;
    }

    // FSM execution
    switch(state) {
        case "IDLE":
            direction = 3;
            door_state = 0;
            if (active_req_count() > 0) {
                const s = evaluate_scan(current_floor, scan_direction);
                if (s.found) {
                    next_floor = s.tgt;
                    scan_direction = s.new_dir;
                    if (s.tgt === current_floor) {
                        state = "DOOR_DWELL";
                        timer = 30;
                        door_state = 1;
                        direction = 3;
                    } else if (s.tgt > current_floor) {
                        state = "MOVING_UP";
                        timer = 30;
                        direction = 1;
                        milestone_log.push(`[${time_s.toFixed(1)}s] Start Moving UP towards Floor ${next_floor} (motor active)`);
                    } else {
                        state = "MOVING_DOWN";
                        timer = 30;
                        direction = 2;
                        milestone_log.push(`[${time_s.toFixed(1)}s] Start Moving DOWN towards Floor ${next_floor} (motor active)`);
                    }
                }
            }
            break;

        case "MOVING_UP":
            direction = 1;
            door_state = 0;
            update_stepper();
            timer--;
            if (timer === 0) {
                current_floor++;
                update_disp();
                milestone_log.push(`[${time_s.toFixed(1)}s] Floor Reached: ${current_floor} (7-seg: 0x${disp.toString(16).toUpperCase()})`);
                if (current_floor === next_floor) {
                    state = "DOOR_DWELL";
                    timer = 30;
                    door_state = 1;
                    direction = 3;
                    milestone_log.push(`[${time_s.toFixed(1)}s] Reached Destination Floor ${current_floor}: DOOR OPEN, Motor IDLE holding torque (q=0x${q.toString(16).toUpperCase()})`);
                } else {
                    timer = 30;
                }
            }
            break;

        case "MOVING_DOWN":
            direction = 2;
            door_state = 0;
            update_stepper();
            timer--;
            if (timer === 0) {
                current_floor--;
                update_disp();
                milestone_log.push(`[${time_s.toFixed(1)}s] Floor Reached: ${current_floor} (7-seg: 0x${disp.toString(16).toUpperCase()})`);
                if (current_floor === next_floor) {
                    state = "DOOR_DWELL";
                    timer = 30;
                    door_state = 1;
                    direction = 3;
                    milestone_log.push(`[${time_s.toFixed(1)}s] Reached Destination Floor ${current_floor}: DOOR OPEN, Motor IDLE holding torque (q=0x${q.toString(16).toUpperCase()})`);
                } else {
                    timer = 30;
                }
            }
            break;

        case "DOOR_DWELL":
            direction = 3;
            door_state = 1;
            if (open_door) {
                timer = 40; // extend wait time
            } else if (close_door) {
                timer = 1; // fast close
            }
            timer--;
            if (timer === 0) {
                door_state = 0;
                // Clear serviced request
                if (scan_direction === 1) {
                    up_call_reg[current_floor] = 0;
                    req_floor_reg[current_floor] = 0;
                } else {
                    down_call_reg[current_floor] = 0;
                    req_floor_reg[current_floor] = 0;
                }
                if (current_floor === 3) scan_direction = 0;
                if (current_floor === 0) scan_direction = 1;

                milestone_log.push(`[${time_s.toFixed(1)}s] Door Closed at Floor ${current_floor}. Remaining requests: ${active_req_count()}`);

                // Evaluate next floor
                if (active_req_count() > 0) {
                    const s = evaluate_scan(current_floor, scan_direction);
                    if (s.found) {
                        next_floor = s.tgt;
                        scan_direction = s.new_dir;
                        if (s.tgt > current_floor) {
                            state = "MOVING_UP";
                            timer = 30;
                            direction = 1;
                            milestone_log.push(`[${time_s.toFixed(1)}s] Next Target: Floor ${next_floor} -> Moving UP`);
                        } else if (s.tgt < current_floor) {
                            state = "MOVING_DOWN";
                            timer = 30;
                            direction = 2;
                            milestone_log.push(`[${time_s.toFixed(1)}s] Next Target: Floor ${next_floor} -> Moving DOWN`);
                        } else {
                            state = "DOOR_DWELL";
                            timer = 30;
                        }
                    } else {
                        state = "IDLE";
                    }
                } else {
                    state = "IDLE";
                    milestone_log.push(`[${time_s.toFixed(1)}s] All requests serviced. System IDLE.`);
                }
            }
            break;
    }
}

for (let c = 0; c < 600; c++) {
    clock_tick();
}

console.log("================================================================================");
console.log("ELEVATOR CONTROLLER TIMING VERIFICATION (0.0s to 60.0s)");
console.log("================================================================================");
console.log(milestone_log.join('\n'));
console.log("================================================================================");
