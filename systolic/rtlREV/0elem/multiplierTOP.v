`timescale 1ns/1ps

module multiplierTOPcpa(
    input [7:0] multiplier,
    input [7:0] multiplicant,
    output [15:0] result
);
    localparam integer size = 8;
    wire [(3*size/2-1):0] encbus;
    wire [((size+1)*size/2-1):0] partialBus;
    wire [(size-2):0] correction;
    wire [15:0] out0;
    wire [15:0] out1;
    booth_encoder #(size) BoothEnc(multiplier, encbus);
    ppgen #(size) ppGenerater(encbus, multiplicant, partialBus, correction);
    dadda8 reductionTree(partialBus, correction, out0, out1);
    wire [15:0] out00 = out0;
    wire [15:0] out11 = out1;
    wire [16:0] finalWire;
    cpa #(16) finalAdder (out00, out11, finalWire);
    assign result = finalWire[15:0];
endmodule

module multiplierTOP(
	input [7:0]  multiplier,
	input [7:0]  multiplicant,
	output[15:0] result0,
	output[15:0] result1);
	localparam integer size =8;
	wire[(3*size/2-1):0]        encbus;
    wire[((size+1)*size/2-1):0] partialBus;
    wire[(size-2):0]            correction;
	booth_encoder#(size) BoothEnc(multiplier,encbus);
	ppgen#(size) ppGenerater(encbus,multiplicant,partialBus,correction);
	dadda8 reductionTree(partialBus,correction,result0,result1);
endmodule

module mulTOPpip(
	input wire        clk,
	input wire [7:0]  multiplier,
	input wire [7:0]  multiplicant,
	output reg [15:0] result0,
	output reg [15:0] result1);
	localparam integer size=8;
	wire[(3*size/2-1):0]        encbus;
	wire[((size+1)*size/2-1):0] partialBus;
	wire[(size-2):0]            correction;
	booth_encoder#(size) BoothEnc(multiplier,encbus);
	ppgen#(size) ppGenerater(encbus,multiplicant,partialBus,correction);
	wire[15:0] result0W, result1W;
	dadda8 reductionTree(partialBus,correction,result0W,result1W);
	always@(posedge clk)begin
		result0 <=result0W;
		result1 <=result1W;
	end
endmodule