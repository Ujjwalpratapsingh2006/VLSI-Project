`timescale 10ms / 1ms

//////////////////////////////////////////////////////////////////////////////////
// Module Name:    seven_seg_disp 
// Description:    7-Segment Display Decoder for Elevator Floor (0, 1, 2, 3)
// Compatibility:  Fully compatible with Xilinx Vivado (Synthesis & Simulation)
//////////////////////////////////////////////////////////////////////////////////

module seven_seg_disp(
    input clk,
    input rst,
    input [1:0] current_floor,
    output reg [7:0] disp
);

    always @(*) begin
        case (current_floor)
            2'b00:   disp = 8'b01111111; // Floor 0 -> '0'
            2'b01:   disp = 8'b00000110; // Floor 1 -> '1'
            2'b10:   disp = 8'b01011011; // Floor 2 -> '2'
            2'b11:   disp = 8'b01001111; // Floor 3 -> '3'
            default: disp = 8'b10000000; // Default segment indicator
        endcase
    end

endmodule
