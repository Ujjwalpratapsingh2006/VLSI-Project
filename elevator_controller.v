`timescale 10ms / 1ms

//////////////////////////////////////////////////////////////////////////////////
// Module Name:    elevator_cont_Machine
// Description:    Top-Level Structural Integration of Intelligent Elevator Controller
//                 - Integrates Core Elevator Controller (elevator)
//                 - Integrates 4-Phase Stepper Motor Controller (stepper_motor)
//                 - Integrates 7-Segment Floor Display Decoder (seven_seg_disp)
// Compatibility:  Fully compatible with Xilinx Vivado (Synthesis, Implementation & Simulation)
//////////////////////////////////////////////////////////////////////////////////

module elevator_cont_Machine(
    input [3:0] move_up_call,
    input [3:0] move_down_call,
    input [3:0] req_floor,
    input clk,
    input rst,
    input open_door,
    input close_door,
    input over_weight,
    output door_state,
    output over_weight_alert,
    output [7:0] disp,
    output [3:0] q
);

    wire [1:0] wire_current_floor;
    wire [1:0] wire_direction;

    // Core Elevator Controller (FSM + SCAN Algorithm)
    elevator ec1 (
        .move_up_call(move_up_call),
        .move_down_call(move_down_call),
        .req_floor(req_floor),
        .clk(clk),
        .rst(rst),
        .over_weight(over_weight),
        .open_door(open_door),
        .close_door(close_door),
        .current_floor(wire_current_floor),
        .direction(wire_direction),
        .door_state(door_state),
        .over_weight_alert(over_weight_alert)
    );

    // 4-Phase Stepper Motor Hoist Driver
    stepper_motor sm1 (
        .clk(clk),
        .rst(rst),
        .direction(wire_direction),
        .q(q)
    );

    // 7-Segment Floor Indicator Decoder
    seven_seg_disp ssd1 (
        .clk(clk),
        .rst(rst),
        .current_floor(wire_current_floor),
        .disp(disp)
    );

endmodule
