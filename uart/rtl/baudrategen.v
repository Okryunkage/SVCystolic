`timescale 1ns/1ps

module baudrategen#(
	parameter clock =100_000_000,
	parameter baudrate =115_200,
	parameter oversample =16)(
	input wire clk,
	output reg RXclk, output reg TXclk
	);
	localparam maxRateRX =clock/(2*baudrate*oversample);
	localparam maxRateTX =clock/(2*baudrate);
	localparam RXcountWidth =$clog2(maxRateRX);
	localparam TXcountWidth =$clog2(maxRateTX);

	reg [(RXcountWidth-1):0] RXcount=0;
	reg [(TXcountWidth-1):0] TXcount=0;

	initial begin
		RXclk =1'b0;
		TXclk =1'b0;
	end

	always@(posedge clk)begin
		if(RXcount==maxRateRX)begin
			RXcount <=0;
			RXclk <=~RXclk;
		end
		else RXcount <=(RXcount +1'b1);
		if(TXcount==maxRateTX)begin
			TXcount <=0;
			TXclk <=~TXclk;
		end
		else TXcount <=(TXcount+1'b1);
	end
endmodule
