`timescale 1ns/1ps

module convSimMemory#(
	parameter int dataWidth=8,depth=16,addrWidth=4,readLatency=2,
	parameter initFile="none",
	parameter bit useInit=0,allowUnwrittenWriteRead=0)(
	input wire logic clk,rst,writeEnable,readEnable,
	input wire logic[addrWidth-1:0] writeAddress,readAddress,
	input wire logic[dataWidth-1:0] writeData,
	output wire logic[dataWidth-1:0] readData);
	logic[dataWidth-1:0] memory[0:depth-1];
	bit written[0:depth-1];
	logic[dataWidth-1:0] pipeline[0:readLatency-1];
	integer fileHandle;
	assign readData=pipeline[readLatency-1];

	initial begin
		if(depth<1 || readLatency<1 || readLatency>100)
			$fatal(1,"convSimMemory: invalid depth or read latency");
		if(useInit)begin
			if(initFile=="none" || initFile=="")
				$fatal(1,"convSimMemory: initialization requires a hex file");
			fileHandle=$fopen(initFile,"r");
			if(fileHandle==0) $fatal(1,"Cannot open memory file: %s",initFile);
			$fclose(fileHandle);
			$readmemh(initFile,memory);
			for(integer a=0;a<depth;a=a+1) written[a]=1;
		end
	end

	always@(posedge clk)begin
		if(writeEnable)begin
			if(int'(writeAddress)>=depth) $fatal(1,"Memory write address out of range");
			memory[writeAddress] <=writeData;
			written[writeAddress] <=1;
		end
		if(rst)begin
			for(integer s=0;s<readLatency;s=s+1) pipeline[s] <='0;
		end
		else begin
			if(readEnable)begin
				if(int'(readAddress)>=depth) $fatal(1,"Memory read address out of range");
				//SPRAM read_first also reads the old word during its first write.
				//That old value is unspecified and is not a valid consumer response.
				if(!written[readAddress] && !(allowUnwrittenWriteRead &&
					writeEnable && writeAddress==readAddress))
					$fatal(1,"%m time=%0t addr=%0d writeEnable=%b allow=%b useInit=%b",
					$time,readAddress,writeEnable,allowUnwrittenWriteRead,useInit);
				// Nonblocking writes preserve the old word on a same-edge collision.
				pipeline[0] <=memory[readAddress];
			end
			// Pending reads advance even when no new request is issued.
			for(integer s=1;s<readLatency;s=s+1) pipeline[s] <=pipeline[s-1];
		end
	end
endmodule

module xpm_memory_spram#(
	parameter int ADDR_WIDTH_A=4,AUTO_SLEEP_TIME=0,BYTE_WRITE_WIDTH_A=8,
	parameter ECC_MODE="no_ecc",MEMORY_INIT_FILE="none",MEMORY_INIT_PARAM="0",
	parameter MEMORY_OPTIMIZATION="true",MEMORY_PRIMITIVE="block",
	parameter int MEMORY_SIZE=128,MESSAGE_CONTROL=0,READ_DATA_WIDTH_A=8,
	parameter int READ_LATENCY_A=2,
	parameter READ_RESET_VALUE_A="0",RST_MODE_A="SYNC",
	parameter int USE_MEM_INIT=1,SIM_ASSERT_CHK=0,
	parameter WAKEUP_TIME="disable_sleep",
	parameter int WRITE_DATA_WIDTH_A=8,
	parameter WRITE_MODE_A="read_first")(
	input wire logic clka,ena,rsta,regcea,sleep,injectsbiterra,injectdbiterra,
	input wire logic[ADDR_WIDTH_A-1:0] addra,
	input wire logic[WRITE_DATA_WIDTH_A-1:0] dina,
	input wire logic[(WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A)-1:0] wea,
	output wire logic[READ_DATA_WIDTH_A-1:0] douta,
	output wire logic sbiterra,dbiterra);
	assign sbiterra=0;
	assign dbiterra=0;
	initial begin
		if(READ_DATA_WIDTH_A!=WRITE_DATA_WIDTH_A || BYTE_WRITE_WIDTH_A!=WRITE_DATA_WIDTH_A ||
			MEMORY_SIZE%WRITE_DATA_WIDTH_A!=0 || WRITE_MODE_A!="read_first" ||
			RST_MODE_A!="SYNC" || READ_RESET_VALUE_A!="0" || ECC_MODE!="no_ecc" ||
			AUTO_SLEEP_TIME!=0 || WAKEUP_TIME!="disable_sleep")
			$fatal(1,"Unsupported xpm_memory_spram simulation configuration");
	end
	always@(posedge clka)
		if(sleep || injectsbiterra || injectdbiterra || !regcea)
			$fatal(1,"SPRAm model requires no sleep/ECC injection and regcea=1");
	convSimMemory#(
		.dataWidth(WRITE_DATA_WIDTH_A),.depth(MEMORY_SIZE/WRITE_DATA_WIDTH_A),
		.addrWidth(ADDR_WIDTH_A),.readLatency(READ_LATENCY_A),
		.initFile(MEMORY_INIT_FILE),.useInit(USE_MEM_INIT!=0),
		.allowUnwrittenWriteRead(1)) storage(
		.clk(clka),.rst(rsta),.writeEnable(ena && wea[0]),.readEnable(ena),
		.writeAddress(addra),.readAddress(addra),.writeData(dina),.readData(douta));
endmodule

module xpm_memory_sdpram#(
	parameter int ADDR_WIDTH_A=4,ADDR_WIDTH_B=4,BYTE_WRITE_WIDTH_A=8,
	parameter CLOCKING_MODE="common_clock",ECC_MODE="no_ecc",
	parameter MEMORY_INIT_FILE="none",MEMORY_INIT_PARAM="0",MEMORY_PRIMITIVE="block",
	parameter int MEMORY_SIZE=128,READ_DATA_WIDTH_B=8,READ_LATENCY_B=2,
	parameter READ_RESET_VALUE_B="0",RST_MODE_B="SYNC",
	parameter int SIM_ASSERT_CHK=1,USE_MEM_INIT=0,WRITE_DATA_WIDTH_A=8,
	parameter WRITE_MODE_B="read_first")(
	input wire logic clka,clkb,ena,enb,rstb,regceb,sleep,injectsbiterra,injectdbiterra,
	input wire logic[ADDR_WIDTH_A-1:0] addra,
	input wire logic[ADDR_WIDTH_B-1:0] addrb,
	input wire logic[WRITE_DATA_WIDTH_A-1:0] dina,
	input wire logic[(WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A)-1:0] wea,
	output wire logic[READ_DATA_WIDTH_B-1:0] doutb,
	output wire logic sbiterrb,dbiterrb);
	assign sbiterrb=0;
	assign dbiterrb=0;
	initial begin
		if(READ_DATA_WIDTH_B!=WRITE_DATA_WIDTH_A || BYTE_WRITE_WIDTH_A!=WRITE_DATA_WIDTH_A ||
			ADDR_WIDTH_A!=ADDR_WIDTH_B || MEMORY_SIZE%WRITE_DATA_WIDTH_A!=0 ||
			CLOCKING_MODE!="common_clock" || WRITE_MODE_B!="read_first" ||
			RST_MODE_B!="SYNC" || READ_RESET_VALUE_B!="0" || ECC_MODE!="no_ecc")
			$fatal(1,"Unsupported xpm_memory_sdpram simulation configuration");
	end
	always@(posedge clka)
		if(sleep || injectsbiterra || injectdbiterra || !regceb)
			$fatal(1,"SDPRAM model requires no sleep/ECC injection and regceb=1");
	// clkb is unused in common_clock mode, as in the configured XPM instance.
	convSimMemory#(
		.dataWidth(WRITE_DATA_WIDTH_A),.depth(MEMORY_SIZE/WRITE_DATA_WIDTH_A),
		.addrWidth(ADDR_WIDTH_A),.readLatency(READ_LATENCY_B),
		.initFile(MEMORY_INIT_FILE),.useInit(USE_MEM_INIT!=0)) storage(
		.clk(clka),.rst(rstb),.writeEnable(ena && wea[0]),.readEnable(enb),
		.writeAddress(addra),.readAddress(addrb),.writeData(dina),.readData(doutb));
endmodule
