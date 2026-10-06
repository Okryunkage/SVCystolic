`timescale 1ns/1ps
`default_nettype none

`ifndef SYNTHESIS
module LUT6#(
    parameter[63:0] INIT =64'h0000_0000_0000_0000)(
    input wire I0, I1, I2, I3, I4, I5,
    output wire O);
    wire[5:0] address ={I5,I4,I3,I2,I1,I0};
    assign O =INIT[address];

endmodule
`endif 
`default_nettype wire
