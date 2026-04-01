`timescale 1ns/1ps

module baudtickgen#(
    parameter integer CLK        =100_000_000,
    parameter integer baudrate   =1_000_000,
    parameter integer oversample =20,
    parameter integer ACCwidth   =24)(
    input  wire clk,
    input  wire rst,
    output wire ostick,
    output wire baudtick
);
    tickgen #(.CLK(CLK),.TICK(baudrate),.ACCwidth(ACCwidth)) baudtickgen(.clk(clk),.rst(rst),.tick(baudtick));
    tickgen #(.CLK(CLK),.TICK(baudrate*oversample),.ACCwidth(ACCwidth)) ostickgen(.clk(clk),.rst(rst),.tick(ostick));
endmodule
