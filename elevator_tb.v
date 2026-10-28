`timescale 10ms / 1ms

//////////////////////////////////////////////////////////////////////////////////
// Testbench Name: elevator_tb
// Description:    Unit Testbench for Core Elevator FSM & SCAN Algorithm
// Compatibility:  Fully compatible with Xilinx Vivado (xsim)
//////////////////////////////////////////////////////////////////////////////////

module elevator_tb;

    reg [3:0] move_up_call;
    reg [3:0] move_down_call;
    reg [3:0] req_floor;
    reg clk;
    reg rst;
    reg over_weight;
    reg open_door;
    reg close_door;

    wire [1:0] current_floor;
    wire [1:0] direction;
    wire door_state;
    wire over_weight_alert;

    elevator uut (
        .move_up_call(move_up_call),
        .move_down_call(move_down_call),
        .req_floor(req_floor),
        .clk(clk),
        .rst(rst),
        .over_weight(over_weight),
        .open_door(open_door),
        .close_door(close_door),
        .current_floor(current_floor),
        .direction(direction),
        .door_state(door_state),
        .over_weight_alert(over_weight_alert)
    );

    initial begin
        move_up_call   = 4'b0000;
        move_down_call = 4'b0000;
        req_floor      = 4'b0000;
        clk            = 1'b0;
        rst            = 1'b1;
        over_weight    = 1'b0;
        open_door      = 1'b0;
        close_door     = 1'b0;

        #20;
        rst = 1'b0;

        #480; move_down_call = 4'b1000; // t = 5.0s
        #100; move_up_call   = 4'b0100; // t = 6.0s
        #400; req_floor      = 4'b0010; // t = 10.0s
        #50;  req_floor      = 4'b0001; // t = 10.5s

        #1400; open_door     = 1'b1;    // t = 24.5s
        #200;  open_door     = 1'b0;

        #650;  close_door    = 1'b1;    // t = 33.0s
        #100;  close_door    = 1'b0;

        #50;   req_floor     = 4'b1000; // t = 34.5s
        #750;  over_weight   = 1'b1;    // t = 42.0s
        #300;  over_weight   = 1'b0;    // t = 45.0s

        #1500;
        $finish;
    end

    always #5 clk = ~clk;

endmodule
