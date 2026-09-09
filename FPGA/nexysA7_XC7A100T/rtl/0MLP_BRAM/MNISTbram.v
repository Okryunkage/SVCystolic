`timescale 1ns/1ps

module fc1w(
	input  wire       clka,
	input  wire       ena,
	input  wire       wea,
	input  wire[12:0] addra,
	input  wire[63:0] dina,
	output wire[63:0] douta);
	pseudoBRAM#(.dataWidth(64),.depth(6272),.addrWidth(13),.Latency(2),.initFile("fc1_w_tile.mem"))
		fc1BRAM(.clka(clka),.ena(ena),.wea(wea),.addra(addra),.dina(dina),.douta(douta));
endmodule
module fc1b(
	input  wire        clka,
	input  wire        ena,
	input  wire        wea,
	input  wire[2:0]   addra,
	input  wire[255:0] dina,
	output wire[255:0] douta);
	pseudoBRAM#(.dataWidth(256),.depth(8),.addrWidth(3),.Latency(2),.initFile("fc1_b_tile.mem"))
		fc1BRAM(.clka(clka),.ena(ena),.wea(wea),.addra(addra),.dina(dina),.douta(douta));
endmodule
module fc2w(
	input  wire       clka,
	input  wire       ena,
	input  wire       wea,
	input  wire[6:0]  addra,
	input  wire[39:0] dina,
	output wire[39:0] douta);
	pseudoBRAM#(.dataWidth(40),.depth(128),.addrWidth(7),.Latency(2),.initFile("fc2_w_tile.mem"))
		fc1BRAM(.clka(clka),.ena(ena),.wea(wea),.addra(addra),.dina(dina),.douta(douta));
endmodule
module fc2b(
	input  wire        clka,
	input  wire        ena,
	input  wire        wea,
	input  wire[0:0]   addra,
	input  wire[159:0] dina,
	output wire[159:0] douta);
	pseudoBRAM#(.dataWidth(160),.depth(2),.addrWidth(1),.Latency(2),.initFile("fc2_b_tile.mem"))
		fc1BRAM(.clka(clka),.ena(ena),.wea(wea),.addra(addra),.dina(dina),.douta(douta));
endmodule