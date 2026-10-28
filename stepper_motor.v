`timescale 10ms / 1ms

//////////////////////////////////////////////////////////////////////////////////
// Module Name:    stepper_motor
// Description:    4-Phase Unipolar Stepper Motor Actuator Driver
//                 Sequence matches physical rotation direction:
//                 - Move UP   (2'b01): 4'h3 -> 4'h9 -> 4'hC -> 4'h6 (CW)
//                 - Move DOWN (2'b10): 4'h6 -> 4'hC -> 4'h9 -> 4'h3 (CCW)
//                 - Stop      (2'b11): Holds state (holding torque)
// Compatibility:  Fully compatible with Xilinx Vivado (Synthesis & Simulation)
//////////////////////////////////////////////////////////////////////////////////

module stepper_motor(
    input clk,
    input rst,
    input [1:0] direction,
    output reg [3:0] q
);

    reg [1:0] state;

    initial begin
        q     = 4'h3;
        state = 2'b00;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q     <= 4'h3;
            state <= 2'b00;
        end else begin
            if (direction == 2'b01 || direction == 2'b10) begin
                case (state)
                    2'd0: q <= (direction == 2'b01) ? 4'h3 : 4'h6;
                    2'd1: q <= (direction == 2'b01) ? 4'h9 : 4'hC;
                    2'd2: q <= (direction == 2'b01) ? 4'hC : 4'h9;
                    2'd3: q <= (direction == 2'b01) ? 4'h6 : 4'h3;
                endcase
                state <= state + 1'b1;
            end else if (direction == 2'b11) begin
                q <= q; // Hold coil excitation state when stopped
            end
        end
    end

endmodule
