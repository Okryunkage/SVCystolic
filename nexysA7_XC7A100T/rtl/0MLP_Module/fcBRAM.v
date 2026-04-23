`timescale 1ns/1ps

module fcBRAM#(
	parameter inNum    =784,
	parameter outNum   =128,
	parameter inWidth  =8,
	parameter wWidth   =8,
	parameter bWidth   =32,
	parameter accWidth =32,
	parameter inSigned =0,
	parameter wMEMfile ="fc_w.mem",
	parameter bMEMfile ="fc_b.mem")(
	input                                    clk,
	input                                    rst,
	input                                    start,
	input            [(inNum*inWidth-1):0]   inFlat,
	output reg                               busy,
	output reg                               done,
	output reg signed[(outNum*accWidth-1):0] outFlat);

	localparam wDepth  =inNum*outNum;
	localparam wAddrW  =$clog2(wDepth);
	localparam bAddrW  =$clog2(outNum);
	localparam inIdxW  =$clog2(inNum);
	localparam outIdxW =$clog2(outNum);

	localparam[2:0] idle     =3'd0;
	localparam[2:0] biasReq  =3'd1;
	localparam[2:0] biasLoad =3'd2;
	localparam[2:0] MAC      =3'd3;
	localparam[2:0] write    =3'd4;

	reg[2:0] state;

	(* ram_style ="block" *) reg signed[(wWidth-1):0] wMEM[0:(wDepth-1)];
	(* ram_style ="block" *) reg signed[(bWidth-1):0] bMEM[0:(bDepth-1)];

	reg[(wAddrW-1):0] waddr;
	reg[(bAddrW-1):0] baddr;
	reg signed[(wWidth-1):0] wdata;
	reg signed[(bWidth-1):0] bdata;

	initial begin
		$readmemh(wMEMfile,wMEM);
		$readmemh(bMEMfile,bMEM);
	end

	always@(posedge clk)begin
		wdata <=wMEM[waddr];
		bdata <=bMEM[baddr];
	end

	