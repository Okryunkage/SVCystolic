`timescale 1ns/1ps

//UART bytes are already normalized signed int8: real = integer/32.
//The host performs normalization; store the two's-complement bits unchanged.
//32 is the fixed-point scale, not the image element width.
//Writes must be 0..783 in order. A write to zero begins a new image.
module mnistImageMEM(
	input logic clk,rst,writeEnable,
	input logic[9:0] writeAddress,
	input logic[7:0] writeData,
	output logic loaded,loadError,
	input logic readEnable,
	input logic[9:0] readAddress,
	output wire logic readValid,
	output wire logic[7:0] readData[0:0]);
	logic[9:0] count;
	logic[1:0] validPipeline;
	wire acceptedWrite =writeEnable && !rst && !readEnable &&
		(writeAddress==0 || (!loaded && writeAddress==count && count<784));
	wire readRequest =readEnable && !rst && !writeEnable && readAddress<784;
	wire[7:0] memoryData;
	assign readData[0] =memoryData;
	assign readValid =validPipeline[1];
	always_ff@(posedge clk)begin
		if(rst)begin
			loaded <=0;
			loadError <=0;
			count <=0;
			validPipeline <=0;
		end
		else begin
			validPipeline <={validPipeline[0],readRequest};
			if(writeEnable)begin
				if(!acceptedWrite)begin
					loadError <=1;
					loaded <=0;
					count <=0;
				end
				else if(writeAddress==0)begin
					count <=1;
					loaded <=0;
					loadError <=0;
				end
				else if(writeAddress==783)begin
					count <=784;
					loaded <=1;
				end
				else count <=count+1'b1;
			end
		end
	end
	xpm_memory_spram#(
		.ADDR_WIDTH_A(10),.BYTE_WRITE_WIDTH_A(8),.ECC_MODE("no_ecc"),
		.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM("0"),.MEMORY_PRIMITIVE("block"),
		.MEMORY_SIZE(784*8),.READ_DATA_WIDTH_A(8),.READ_LATENCY_A(2),
		.READ_RESET_VALUE_A("0"),.RST_MODE_A("SYNC"),.USE_MEM_INIT(0),
		.WRITE_DATA_WIDTH_A(8),.WRITE_MODE_A("read_first")) memory(
		.clka(clk),.ena(acceptedWrite || readRequest),.wea(acceptedWrite),
		.addra(acceptedWrite?writeAddress:readAddress),.dina(writeData),
		.douta(memoryData),.regcea(1'b1),.rsta(rst),.sleep(1'b0),
		.injectsbiterra(1'b0),.injectdbiterra(1'b0),.sbiterra(),.dbiterra());
endmodule
