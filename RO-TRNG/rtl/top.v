`timescale 1ns/1ps
`default_nettype none

module top#(
	parameter integer NINV =3,
	parameter integer NRO  =13,
	parameter integer LUTprob0 =4,
	parameter integer LUTprob1 =8,
	parameter integer LUTprob2 =12,
	parameter integer LUTprob3 =16)(

	input wire  clk, rst, rst,
	input wire  [1:0] LUTprobSEL,
	input wire  [3:0] MUXprob,
	output wire LUTrngBIT, LUTrngVALID, MUXrngBIT, MUXrngVALID);

	(*ASYNC_REG="TRUE"*) reg[1:0] rstSync     =2'b00;
	(*ASYNC_REG="TRUE"*) reg[1:0] LUTselMETA  =2'b00;
	(*ASYNC_REG="TRUE"*) reg[1:0] LUTselSYNC  =2'b00;
	(*ASYNC_REG="TRUE"*) reg[3:0] MUXprobMETA =4'b0000;
	(*ASYNC_REG="TRUE"*) reg[3:0] MUXprobSYNC =4'b0000;

	always@(posedge clk)begin
	  rstSync     <={rstSync[0], rst};
	  LUTselMETA  <=LUTprobSEL;
	  LUTselSYNC  <=LUTselMETA;
	  MUXprobMETA <=MUXprob;
	  MUXprobSYNC <=MUXprobMETA;
	end

	wire rstI =rstSync[1];
	wire[NRO-1:0] rawROout;

	genvar roIndex;
	generate
		for(roIndex=0;roIndex<NRO;roIndex=roIndex+1)begin:GEN_RO
			(*keep_hierarchy="yes",dont_touch="true"*)
			RO#(.NINV(NINV)) uRO(.en(1'b1),.raw_ro(rawROout[roIndex]));
		end
	endgenerate

	(*keep_hierarchy="yes",dont_touch="true"*)
	reg[NRO-1:0] sampledRO ={NRO{1'b0}};

	always@(posedge clk)begin
		if(rstI) sampledRO <={NRO{1'b0}};
		else     sampledRO <=rawROout;
	end

	wire xorBit =^sampledRO;

	reg rawRNGbit =1'b0;
	always@(posedge clk)begin
		if(rstI) rawRNGbit <=1'b0;
		else     rawRNGbit <=xorBit;
	end

	sng_lut#(
		.prob0(LUTprob0), .prob1(LUTprob1),
		.prob2(LUTprob2), .prob3(LUTprob3)) u_sng_lut(
		.clk(clk), .rst(rstI),
		.rawBit(rawRNGbit), .probSel(LUTselSYNC),
		.randomBit(LUTrngBIT), .randomValid(LUTrngVALID));
	
	sng_mux u_sng_mux(
		.clk(clk), .rst(rstI),
		.rawBit(rawRNGbit), .probability(MUXprobSYNC),
		.randomBit(MUXrngBIT), .randomValid(MUXrngVALID));

endmodule