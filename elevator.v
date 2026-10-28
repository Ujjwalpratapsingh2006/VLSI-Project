`timescale 10ms / 1ms

//////////////////////////////////////////////////////////////////////////////////
// Module Name:    elevator
// Description:    Intelligent 4-Floor SCAN (Elevator Algorithm) Controller
//                 - Synchronous Hierarchical Finite State Machine
//                 - Edge-Triggered Button Latching (eliminates false re-triggers)
//                 - Starvation-Free SCAN Scheduling Look-Ahead
//                 - Safe Hardware Interlocks (Overload Sensor, Door Dwell)
//                 - Hardware Counter-Based Timing (3.0s per floor, 3.0s door dwell)
// Compatibility:  Fully compatible with Xilinx Vivado (xsim, Synthesis, Implementation)
//////////////////////////////////////////////////////////////////////////////////

module elevator(
    input [3:0] move_up_call,     // Hall call buttons (UP): floors 0, 1, 2
    input [3:0] move_down_call,   // Hall call buttons (DOWN): floors 1, 2, 3
    input [3:0] req_floor,        // Internal cabin destination buttons (0-3)
    input clk,                    // System clock (100ms period in testbench)
    input rst,                    // Reset signal
    input over_weight,            // Overload safety sensor (> 750 kg)
    input open_door,              // Manual door re-open override button
    input close_door,             // Manual door fast-close override button
    output reg [1:0] current_floor, // Decoded current floor (0-3)
    output reg [1:0] direction,     // Motor direction: 2'b01=UP, 2'b10=DOWN, 2'b11=STOP
    output reg door_state,          // Door: 0=CLOSED, 1=OPEN
    output reg over_weight_alert    // Safety alarm: 1=ACTIVE, 0=NORMAL
);

    // Floor parameters
    parameter f0 = 2'b00;
    parameter f1 = 2'b01;
    parameter f2 = 2'b10;
    parameter f3 = 2'b11;

    // Direction parameters
    parameter move_up   = 2'b01;
    parameter move_down = 2'b10;
    parameter stop      = 2'b11;

    // Door state parameters
    parameter door_open  = 1'b1;
    parameter door_close = 1'b0;

    // Timing constants (measured in clock cycles where 1 cycle = 100ms)
    // 3.0 seconds = 30 clock cycles
    localparam TRANSIT_CYCLES   = 8'd30; // 3.0 sec to travel between adjacent floors
    localparam DWELL_CYCLES     = 8'd30; // 3.0 sec default door open time
    localparam EXTEND_CYCLES    = 8'd40; // 4.0 sec extra door time on open_door override

    // FSM State Encoding
    localparam S_IDLE        = 3'd0;
    localparam S_SCAN        = 3'd1;
    localparam S_MOVING_UP   = 3'd2;
    localparam S_MOVING_DOWN = 3'd3;
    localparam S_DOOR_DWELL  = 3'd4;

    reg [2:0] state;
    reg [1:0] next_floor;
    reg       scan_direction; // 1 = UPWARD, 0 = DOWNWARD
    reg [7:0] timer;

    // Edge detection delay registers
    reg [3:0] move_up_call_d;
    reg [3:0] move_down_call_d;
    reg [3:0] req_floor_d;

    wire [3:0] move_up_edge   = move_up_call & ~move_up_call_d;
    wire [3:0] move_down_edge = move_down_call & ~move_down_call_d;
    wire [3:0] req_floor_edge = req_floor & ~req_floor_d;

    // Request registration latches
    reg [3:0] up_call_reg;
    reg [3:0] down_call_reg;
    reg [3:0] req_floor_reg;

    // Request clearing pulse
    reg clear_req;

    // Total active request calculation
    wire [3:0] active_req_count = 
        up_call_reg[0] + up_call_reg[1] + up_call_reg[2] +
        down_call_reg[1] + down_call_reg[2] + down_call_reg[3] +
        req_floor_reg[0] + req_floor_reg[1] + req_floor_reg[2] + req_floor_reg[3];

    // Priority-based SCAN Look-Ahead Function
    function [3:0] evaluate_scan;
        input [1:0] cur;
        input       dir;
        input [3:0] up_r;
        input [3:0] dn_r;
        input [3:0] in_r;
        reg         found;
        reg [1:0]   tgt;
        reg         new_dir;
        integer     idx;
        begin
            found   = 1'b0;
            tgt     = cur;
            new_dir = dir;

            if (dir == 1'b1) begin // UPWARD SWEEP
                // 1. Search upward from current floor to floor 3
                for (idx = 0; idx <= 3; idx = idx + 1) begin
                    if (!found && (idx >= cur) && (up_r[idx] || in_r[idx])) begin
                        tgt     = idx[1:0];
                        new_dir = (idx == 3) ? 1'b0 : 1'b1;
                        found   = 1'b1;
                    end
                end
                // 2. If nothing found above, turnaround to DOWN and sweep 3 down to 0
                if (!found) begin
                    for (idx = 3; idx >= 0; idx = idx - 1) begin
                        if (!found && (dn_r[idx] || in_r[idx])) begin
                            tgt     = idx[1:0];
                            new_dir = (idx == 0) ? 1'b1 : 1'b0;
                            found   = 1'b1;
                        end
                    end
                end
                // 3. Fallback: check any remaining up calls below current floor
                if (!found) begin
                    for (idx = 0; idx <= 3; idx = idx + 1) begin
                        if (!found && (up_r[idx] || in_r[idx])) begin
                            tgt     = idx[1:0];
                            new_dir = 1'b1;
                            found   = 1'b1;
                        end
                    end
                end
            end else begin // DOWNWARD SWEEP
                // 1. Search downward from current floor to floor 0
                for (idx = 3; idx >= 0; idx = idx - 1) begin
                    if (!found && (idx <= cur) && (dn_r[idx] || in_r[idx])) begin
                        tgt     = idx[1:0];
                        new_dir = (idx == 0) ? 1'b1 : 1'b0;
                        found   = 1'b1;
                    end
                end
                // 2. If nothing found below, turnaround to UP and sweep 0 up to 3
                if (!found) begin
                    for (idx = 0; idx <= 3; idx = idx + 1) begin
                        if (!found && (up_r[idx] || in_r[idx])) begin
                            tgt     = idx[1:0];
                            new_dir = (idx == 3) ? 1'b0 : 1'b1;
                            found   = 1'b1;
                        end
                    end
                end
                // 3. Fallback: check any remaining down calls above current floor
                if (!found) begin
                    for (idx = 3; idx >= 0; idx = idx - 1) begin
                        if (!found && (dn_r[idx] || in_r[idx])) begin
                            tgt     = idx[1:0];
                            new_dir = 1'b0;
                            found   = 1'b1;
                        end
                    end
                end
            end
            evaluate_scan = {found, new_dir, tgt};
        end
    endfunction

    // Wire to receive SCAN evaluation
    wire [3:0] scan_result = evaluate_scan(current_floor, scan_direction, up_call_reg, down_call_reg, req_floor_reg);
    wire       scan_found  = scan_result[3];
    wire       scan_next_d = scan_result[2];
    wire [1:0] scan_target = scan_result[1:0];

    // Initialization
    initial begin
        current_floor     = f0;
        next_floor        = f0;
        direction         = stop;
        door_state        = door_close;
        over_weight_alert = 1'b0;
        scan_direction    = 1'b1; // Start scanning UP
        state             = S_IDLE;
        timer             = 8'd0;
        clear_req         = 1'b0;
        move_up_call_d    = 4'b0000;
        move_down_call_d  = 4'b0000;
        req_floor_d       = 4'b0000;
        up_call_reg       = 4'b0000;
        down_call_reg     = 4'b0000;
        req_floor_reg     = 4'b0000;
    end

    // Input Request Registration Bank (Edge-Detected)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            move_up_call_d   <= 4'b0000;
            move_down_call_d <= 4'b0000;
            req_floor_d      <= 4'b0000;
            up_call_reg      <= 4'b0000;
            down_call_reg    <= 4'b0000;
            req_floor_reg    <= 4'b0000;
        end else begin
            move_up_call_d   <= move_up_call;
            move_down_call_d <= move_down_call;
            req_floor_d      <= req_floor;

            // Latch hall and cabin button presses on positive edge
            if (move_up_edge[0]) up_call_reg[0] <= 1'b1;
            if (move_up_edge[1]) up_call_reg[1] <= 1'b1;
            if (move_up_edge[2]) up_call_reg[2] <= 1'b1;

            if (move_down_edge[1]) down_call_reg[1] <= 1'b1;
            if (move_down_edge[2]) down_call_reg[2] <= 1'b1;
            if (move_down_edge[3]) down_call_reg[3] <= 1'b1;

            if (req_floor_edge[0]) req_floor_reg[0] <= 1'b1;
            if (req_floor_edge[1]) req_floor_reg[1] <= 1'b1;
            if (req_floor_edge[2]) req_floor_reg[2] <= 1'b1;
            if (req_floor_edge[3]) req_floor_reg[3] <= 1'b1;

            // Clear served requests upon door dwell completion
            if (clear_req) begin
                if (scan_direction == 1'b1) begin
                    up_call_reg[current_floor]   <= 1'b0;
                    req_floor_reg[current_floor] <= 1'b0;
                end else begin
                    down_call_reg[current_floor] <= 1'b0;
                    req_floor_reg[current_floor] <= 1'b0;
                end
            end
        end
    end

    // Synchronous FSM: Motion, Door Dwell, Safety Interlocks & SCAN
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_floor     <= f0;
            next_floor        <= f0;
            direction         <= stop;
            door_state        <= door_close;
            over_weight_alert <= 1'b0;
            scan_direction    <= 1'b1;
            state             <= S_IDLE;
            timer             <= 8'd0;
            clear_req         <= 1'b0;
        end else begin
            clear_req <= 1'b0; // default pulse low

            // Safety Interlock: Emergency Overweight Detection
            if (over_weight) begin
                over_weight_alert <= 1'b1;
                direction         <= stop;
                door_state        <= door_open; // Force doors open to prevent passenger entrapment
                // Freeze timer while overweight condition persists
            end else begin
                over_weight_alert <= 1'b0;

                case (state)
                    // IDLE State: Wait for any valid request
                    S_IDLE: begin
                        direction  <= stop;
                        door_state <= door_close;
                        timer      <= 8'd0;
                        if (active_req_count > 0 && scan_found) begin
                            next_floor     <= scan_target;
                            scan_direction <= scan_next_d;
                            if (scan_target == current_floor) begin
                                direction  <= stop;
                                door_state <= door_open;
                                timer      <= DWELL_CYCLES;
                                state      <= S_DOOR_DWELL;
                            end else if (scan_target > current_floor) begin
                                direction  <= move_up;
                                door_state <= door_close;
                                timer      <= TRANSIT_CYCLES;
                                state      <= S_MOVING_UP;
                            end else begin
                                direction  <= move_down;
                                door_state <= door_close;
                                timer      <= TRANSIT_CYCLES;
                                state      <= S_MOVING_DOWN;
                            end
                        end
                    end

                    // Moving Upwards towards next_floor
                    S_MOVING_UP: begin
                        direction  <= move_up;
                        door_state <= door_close;
                        if (timer > 8'd1) begin
                            timer <= timer - 1'b1;
                        end else begin
                            // Arrived at next adjacent floor
                            current_floor <= current_floor + 1'b1;
                            if ((current_floor + 1'b1) == next_floor) begin
                                // Reached destination floor
                                direction  <= stop;
                                door_state <= door_open;
                                timer      <= DWELL_CYCLES;
                                state      <= S_DOOR_DWELL;
                            end else begin
                                // Continue transit to subsequent floor
                                timer <= TRANSIT_CYCLES;
                            end
                        end
                    end

                    // Moving Downwards towards next_floor
                    S_MOVING_DOWN: begin
                        direction  <= move_down;
                        door_state <= door_close;
                        if (timer > 8'd1) begin
                            timer <= timer - 1'b1;
                        end else begin
                            // Arrived at next adjacent floor
                            current_floor <= current_floor - 1'b1;
                            if ((current_floor - 1'b1) == next_floor) begin
                                // Reached destination floor
                                direction  <= stop;
                                door_state <= door_open;
                                timer      <= DWELL_CYCLES;
                                state      <= S_DOOR_DWELL;
                            end else begin
                                // Continue transit to subsequent floor
                                timer <= TRANSIT_CYCLES;
                            end
                        end
                    end

                    // Door Dwell & Passenger Service State
                    S_DOOR_DWELL: begin
                        direction  <= stop;
                        door_state <= door_open;

                        // Manual Door Re-open Override
                        if (open_door) begin
                            timer <= EXTEND_CYCLES; // Extend waiting time
                        end
                        // Manual Fast-Close Override
                        else if (close_door) begin
                            timer <= 8'd1; // Close immediately
                        end

                        if (timer > 8'd1) begin
                            timer <= timer - 1'b1;
                        end else begin
                            // Dwell complete: close door and clear serviced request
                            door_state <= door_close;
                            clear_req  <= 1'b1;

                            // Turnaround at boundaries
                            if (current_floor == f3) scan_direction <= 1'b0;
                            if (current_floor == f0) scan_direction <= 1'b1;

                            state <= S_SCAN;
                        end
                    end

                    // Arbitrate Next Floor in SCAN order
                    S_SCAN: begin
                        if (active_req_count > 0 && scan_found) begin
                            next_floor     <= scan_target;
                            scan_direction <= scan_next_d;
                            if (scan_target == current_floor) begin
                                direction  <= stop;
                                door_state <= door_open;
                                timer      <= DWELL_CYCLES;
                                state      <= S_DOOR_DWELL;
                            end else if (scan_target > current_floor) begin
                                direction  <= move_up;
                                door_state <= door_close;
                                timer      <= TRANSIT_CYCLES;
                                state      <= S_MOVING_UP;
                            end else begin
                                direction  <= move_down;
                                door_state <= door_close;
                                timer      <= TRANSIT_CYCLES;
                                state      <= S_MOVING_DOWN;
                            end
                        end else begin
                            direction  <= stop;
                            door_state <= door_close;
                            state      <= S_IDLE;
                        end
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
