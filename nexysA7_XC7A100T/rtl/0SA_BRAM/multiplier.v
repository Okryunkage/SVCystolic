`timescale 1ns/1ps
/*
module radix4booth(
	input wire [2:0] in,
	output wire [2:0] out);
	reg [2:0] outreg;
	assign out =outreg;
	always @(*) begin
		case(in)
			3'b000, 3'b111: outreg =3'b000;
			3'b001, 3'b010: outreg =3'b001;
			3'b011        : outreg =3'b010;
			3'b100        : outreg =-3'sd2;
			3'b101, 3'b110: outreg =3'b111;
			default       : outreg =3'b000;
		endcase
	end
endmodule
*/
module radix4booth(
	input wire [2:0] in,
	output wire [2:0] result);
	function [2:0] booth; //task
		input [2:0] in; begin
			case(in)
				3'b000, 3'b111: booth =3'b000;
				3'b001, 3'b010: booth =3'b001;
				3'b011        : booth =3'b010;
				3'b100        : booth =3'b110;
				3'b101, 3'b110: booth =3'b111;
				default       : booth =3'b000;
			endcase
		end
	endfunction
	assign result =booth(in);
endmodule

module booth_encoder #(
	parameter integer size = 8)(
	input wire[(size-1):0] multiplier,
	output wire [(3*size/2-1):0] result);
	genvar i;
	generate
		for(i=0; i<(size/2); i=i+1) begin: booth
			wire [2:0] y;
			//assign y = {multiplier[2*i+1], multiplier[2*i], (i==0?1'b0:multiplier[2*i-1])};
			if(i==0) assign y ={multiplier[1], multiplier[0], 1'b0};
			else assign y ={multiplier[2*i+1], multiplier[2*i], multiplier[2*i-1]};
			radix4booth boothENC(y, result[(3*i+2):(3*i)]);
		end
	endgenerate
endmodule

module ppgen #(
	parameter integer size=8)(
	input [(3*size/2-1):0] encbus,
	input [(size-1):0] multiplicand,
	output [((size+1)*size/2-1):0] ppbus,
	output wire [(size-2):0] correction);
	//wire signed [(2*size-1):0] mul_ext = {{size{multiplicant[size-1]}}, multiplicant};
	genvar i;
	generate
		for(i=0;i<(size/2);i=i+1)begin: ppg
			wire[2:0] enc;
			assign enc = encbus[(3*i+2):(3*i)];
			wire signed [size:0] mag;
			assign mag = (enc==3'b001||enc==3'b111)?{multiplicand[size-1],multiplicand}:
				(enc==3'b010||enc==3'b110)?{multiplicand,1'b0}:{(size+1){1'b0}};
			wire [size:0] ppr = (mag ^ {(size+1){enc[2]}});
			//assign ppbus[((size+1)*(i+1)-1) -:(size+1)] = {(size-2*i-1){ppr[size]},ppr,(2*i){1'b0}}; //-:
			assign ppbus[((size+1)*(i+1)-1) -:(size+1)] = ppr;
		end
	endgenerate
	genvar j;
	generate
		for(j=0;j<(size-1);j=j+1)begin: corr
			if((j%2)==0) assign correction[j] = encbus[3*(j/2)+2];
			else assign correction[j] = 1'b0;
		end
	endgenerate
endmodule
