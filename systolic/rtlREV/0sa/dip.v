`timescale 1ns/1ps

module dip#(
	parameter integer size=16)(
	clk, en, weight, in, result);

	function rowPEsize;
		input integer row;begin
			if((row+1)<3) rowPEsize =3;
			else          rowPEsize =row+1;
		end
	endfunction

	function integer rowbussize;
		input integer row;begin
			rowbussize =16+$clog2(row+1);
		end
	endfunction

	function integer finalPEsize;
		input integer value;begin
			if(value<3) finalPEsize =3;
			else        finalPEsize =value;
		end
	endfunction

	localparam integer bussize =16+$clog2(finalPEsize(size));
	localparam integer buswire =bussize-1;

	input wire clk, en;
	input wire [7:0]       weight[(size-1):0];
	input wire [7:0]       in    [(size-1):0];
	output wire[buswire:0] result[(size-1):0];

	genvar i,j;
	generate
		for(i=0;i<size;i=i+1)begin:c
			for(j0;j<size;j=j+1)begin:r
				localparam integer rowbussizeP =rowbussize(j);
				localparam integer rowbuswireP =rowbussizeP-1;
				wire[11:0] encP;
				wire[7:0]  inP;
				wire[(rowbuswireP-k):0] psum0P;
				wire[rowbuswireP:0] psum1P;
			end
		end
	endgenerate
	generate
		for(i=0;i<size;i=i+1)begin:column
			localparam integer row0PEsizse =rowPEsize(0);
			localparam integer row0bussize =16+$clog2(row0PEsize);
			wire[11:0] encW;
			wire[buswire:0] psum0Shift;
			wire[buswire:0] resultP;
			booth_encoder#(8) WENC(.multiplier(weight[i]),.result(encW));
			HA_FSA_enc#(.size())
