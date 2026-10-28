`timescale 10ms / 1ms

//////////////////////////////////////////////////////////////////////////////////
// Testbench Name: elevator_cont_Machine_tb
// Description:    Full-System Verification Testbench for Intelligent Elevator Controller
//                 Matches the exact 60-second test sequence shown in OUTPUT.png, 
//                 OUTPUT1.png, OUTPUT2.png, and OUTPUT3.png:
//                 - Multi-Floor Request Registration
//                 - 4-Phase Stepper Motor Hoist Sequencing (CW/CCW/Holding)
//                 - 7-Segment Floor Display Decoding (0, 1, 2, 3)
//                 - Door Re-open Override (open_door)
//                 - Fast Door Close Override (close_door)
//                 - Overload Safety Interlock (over_weight & alert)
// Compatibility:  Fully compatible with Xilinx Vivado (xsim)
//////////////////////////////////////////////////////////////////////////////////

module elevator_cont_Machine_tb;

    // Inputs to Unit Under Test (UUT)
    reg [3:0] move_up_call;
    reg [3:0] move_down_call;
    reg [3:0] req_floor;
    reg clk;
    reg rst;
    reg open_door;
    reg close_door;
    reg over_weight;

    // Outputs from UUT
    wire door_state;
    wire over_weight_alert;
    wire [7:0] disp;
    wire [3:0] q;

    // Instantiate the Unit Under Test (UUT)
    elevator_cont_Machine uut (
        .move_up_call(move_up_call),
        .move_down_call(move_down_call),
        .req_floor(req_floor),
        .clk(clk),
        .rst(rst),
        .open_door(open_door),
        .close_door(close_door),
        .over_weight(over_weight),
        .door_state(door_state),
        .over_weight_alert(over_weight_alert),
        .disp(disp),
        .q(q)
    );

    initial begin
        // Initialize Inputs
        move_up_call   = 4'b0000;
        move_down_call = 4'b0000;
        req_floor      = 4'b0000;
        clk            = 1'b0;
        rst            = 1'b1;
        open_door      = 1'b0;
        close_door     = 1'b0;
        over_weight    = 1'b0;

        // Release reset pulse at 200ms
        #20;
        rst = 1'b0;

        // 1. At t = 5.0s: Floor 3 Down Hall Call
        #480;
        move_down_call = 4'b1000;

        // 2. At t = 6.0s: Floor 2 Up Hall Call
        #100;
        move_up_call = 4'b0100;

        // 3. At t = 10.0s: Cabin Destination Request: Floor 1
        #400;
        req_floor = 4'b0010;

        // 4. At t = 10.5s: Cabin Destination Request: Floor 0
        #50;
        req_floor = 4'b0001;

        // 5. At t = 24.5s: Door Re-open Request (extending dwell time at Floor 1)
        #1400;
        open_door = 1'b1;

        #200;
        open_door = 1'b0;

        // 6. At t = 33.0s: Fast Close Request (closing doors immediately at Floor 0)
        #650;
        close_door = 1'b1;

        #100;
        close_door = 1'b0;

        // 7. At t = 34.5s: Cabin Destination Request: Floor 3
        #50;
        req_floor = 4'b1000;

        // 8. At t = 42.0s: Emergency Overload Trigger (> 750 kg)
        #750;
        over_weight = 1'b1;

        // 9. At t = 45.0s: Overweight condition resolved
        #300;
        over_weight = 1'b0;

        // 10. Allow simulation to complete the final travel to Floor 3
        #1500;
        $display("--------------------------------------------------------------------------------");
        $display("[VIVADO SIMULATION COMPLETE] 60-Second Full System Verification Finished.");
        $display("--------------------------------------------------------------------------------");
        $finish;
    end

    // 100ms Clock Generator (50ms HIGH, 50ms LOW -> 10 Hz)
    always #5 clk = ~clk;

endmodule
