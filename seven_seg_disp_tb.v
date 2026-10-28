`timescale 10ms / 1ms

//////////////////////////////////////////////////////////////////////////////////
// Testbench Name: seven_seg_disp_tb
// Description:    Unit Testbench for 7-Segment Floor Decoder
// Compatibility:  Fully compatible with Xilinx Vivado (xsim)
//////////////////////////////////////////////////////////////////////////////////

module seven_seg_disp_tb;

    reg clk;
    reg rst;
    reg [1:0] current_floor;
    wire [7:0] disp;

    seven_seg_disp uut (
        .clk(clk),
        .rst(rst),
        .current_floor(current_floor),
        .disp(disp)
    );

    initial begin
        clk           = 1'b0;
        rst           = 1'b0;
        current_floor = 2'b00;

        #100; current_floor = 2'b01; // Floor 1
        #100; current_floor = 2'b10; // Floor 2
        #100; current_floor = 2'b11; // Floor 3
        #100; current_floor = 2'b00; // Floor 0

        #200;
        $finish;
    end

endmodule
