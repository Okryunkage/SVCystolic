`timescale 1ns/1ps

module fc#(
	parameter inNum =8,
	parameter outNum =16,
	parameter inWidth =1,
	parameter wWidth =8,
	parameter bWidth =8,
	parameter outWidth =16,
	parameter inSigned =0)(
	input wire[(inNum*inWidth-1):0] inFlat,
	input wire[(outNum*inNum*wWidth-1):0] wFlat,
	input wire[(outNum*bWidth-1):0] bFlat,
	output reg signed [(outNum*outWidth-1):0] outFlat);

	integer o,i;
	reg signed[(outWidth-1):0] acc;
	reg signed[(outWidth-1):0] inExt;
	reg signed[(outWidth-1):0] wExt;
	reg signed[(2*outWidth-1):0] multResult;

	function signed[(outWidth-1):0] inExtend;
		input[(inWidth-1):0] in;
		begin
			if(inSigned) inExtend ={{(outWidth-inWidth){in[inWidth-1]}},in};
			else inExtend ={{(outWidth-inWidth){1'b0}},in};
		end
	endfunction

	function signed[(outWidth-1):0] wExtend;
		input[(wWidth-1):0] in;
		begin
			wExtend ={{(outWidth-wWidth){in[wWidth-1]}},in};
		end
	endfunction

	function signed[(outWidth-1):0] bExtend;
		input[(bWidth-1):0] in;
		begin
			bExtend ={{(outWidth-bWidth){in[bWidth-1]}},in};
		end
	endfunction

	always@*begin
		outFlat ={(outNum*outWidth){1'b0}};
		for(o=0;o<outNum;o=o+1)begin
			acc =bExtend(bFlat[(o*bWidth)+:bWidth]);

			for(i=0;i<inNum;i=i+1)begin
				inExt =inExtend(inFlat[(i*inWidth)+:inWidth]);
				wExt =wExtend(wFlat[(((o*inNum)+i)*wWidth)+:wWidth]);
				multResult =inExt*wExt;

				acc =acc+ $signed(multResult[(outWidth-1):0]);
			end
			outFlat[(o*outWidth)+:outWidth] =acc;
		end
	end
endmodule