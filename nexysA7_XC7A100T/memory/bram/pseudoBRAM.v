`timescale 1ns/1ps

module BRAM#(
	parameter integer dataWidth =8,
	parameter integer depth     =256,
	parameter integer addrWidth =8,
	parameter integer Latency   =2,
	parameter         initFile  ="init.mem")(
	input wire clka,
	input wire ena,
	input wire wea,
	input wire[(addrWidth-1):0] addra,
	input wire[(dataWidth-1):0] dina,
	output reg[(dataWidth-1):0] douta);

	reg[(dataWidth-1):0] mem[0:(depth-1)];
	initial begin
		$readmemh(initFile,mem);
	end
	generate
		if(Latency==1)begin:Latency1
			always@(posedge clka)begin
				if(ena)begin
					if(wea) mem[addra] <=dina;
					douta <=mem[addra];
				end
			end
		end
		else if(Latency==2)begin:Latency2
			reg[(dataWidth-1):0] doutPIPE;
			always@(posedge clka)begin
				if(ena)begin
					if(wea) mem[addra] <= dina;
					doutPIPE <=mem[addra];
					douta    <=doutPIPE;
				end
			end
		end
		else begin:LatencyNON
			initial begin
				$display("ERROR:readLatency over 2");
				$finish;
			end
		end
	endgenerate
endmodule