`timescale 10ms / 1ms

//////////////////////////////////////////////////////////////////////////////////
// Testbench Name: stepper_motor_tb
// Description:    Unit Testbench for 4-Phase Stepper Motor Controller
// Compatibility:  Fully compatible with Xilinx Vivado (xsim)
//////////////////////////////////////////////////////////////////////////////////

module stepper_motor_tb;

    reg clk;
    reg rst;
    reg [1:0] direction;
    wire [3:0] q;

    stepper_motor uut (
        .clk(clk),
        .rst(rst),
        .direction(direction),
        .q(q)
    );

    initial begin
        clk       = 1'b0;
        rst       = 1'b1;
        direction = 2'b10; // DOWN

        #20;
        rst = 1'b0;

        #100; direction = 2'b11; // STOP
        #300; direction = 2'b01; // UP
        #300; direction = 2'b11; // STOP

        #500;
        $finish;
    end

    always #5 clk = ~clk;

endmodule
