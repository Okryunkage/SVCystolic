(* keep_hierarchy = "yes", dont_touch = "true" *)
module RO#(
	parameter integer NINV =13)(    
	input  wire en,
	output wire raw_ro);

	(* dont_touch = "yes" *) wire [NINV:0] x;
	(* dont_touch = "yes" *) wire          y;
	
	genvar i;
	generate
		for (i=0; i<NINV; i=i+1)begin:g_inv
			(* keep = "true", dont_touch = "yes" *)
			LUT1#(.INIT(2'b01)) u_inv(.O (x[i+1]),.I0(x[i]));
			//LUT is 1 input LUT primitive in Xillinx FPGA
			//if INIT==2'b00, O =0
			//if INIT==2'b01, O =~I0
			//if INIT==2'b10, O =I0
			//if INIT==2'b11, O =1
		end
	endgenerate
	assign y      =x[NINV];
	assign x[0]   =en&y;
	assign raw_ro =x[NINV];
endmodule
