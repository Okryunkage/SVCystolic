`timescale 1ns/1ps

/*
Simulation model for Xililinx xpm_memory_spram
This is not a replacement for Vivado XPM.
Use this only for RTL simulation with tools like iverilog

Supported roughly:
	-single-port synchronous RAM
	-ena
	-wea byte/word write enable
	-READ_LATENCY_A >=1
	-WRITE_MODE_A ="read_first", "write_first", "no_change"
	-MEMORY_INIT_FILE via $readmemh

SImplifications:
	-ECC is ignored
	-sleep is ignored
	-READ_RESET_VALUE_A is treated as 0
	-asymmetric read/write widths are not accurately modeled
*/

module xpm_memory_spram_sim#(
	parameter integer ADDR_WIDTH_A        =6,
	parameter integer AUTO_SLEEP_TIME     =0,
	parameter integer BYTE_WRITE_WIDTH_A  =32,
	parameter         CASCADE_HEIGHT      =0,
	parameter         ECC_MODE            ="no_ecc",
	parameter         MEMORY_INIT_FILE    ="none",
	parameter         MEMORY_INIT_PARAM   ="0",
	parameter         MEMORY_OPTIMIZATION ="true",
	parameter         MEMORY_PRIMITIVE    ="auto",
	parameter integer MEMORY_SIZE         =2048,
	parameter integer MESSAGE_CONTROL     =0,
	parameter integer READ_DATA_WIDTH_A   =32,
	parameter integer READ_LATENCY_A      =1,
	parameter         READ_RESET_VALUE_A  ="0",
	parameter         RST_MODE_A          ="SYNC",
	parameter integer SIM_ASSERT_CHK      =0,
	parameter integer USE_MEM_INIT        =1,
	parameter integer USE_MEM_INIT_MMI    =0,
	parameter         WAKEUP_TIME         ="disable_sleep",
	parameter integer WRITE_DATA_WIDTH_A  =32,
	parameter         WRITE_MODE_A        ="read_first")(

	output wire                         dbiterra,
	output reg  [READ_DATA_WIDTH_A-1:0] douta,
	output wire                         sbiterra,

	input  wire [ADDR_WIDTH_A-1:0]      addra,
	input  wire                         clka,
	input  wire [WRITE_DATA_WIDTH_A-1:0] dina,
	input  wire                         ena,
	input  wire                         injectdbiterra,
	input  wire                         injectsbiterra,
	input  wire                         regcea,
	input  wire                         rsta,
	input  wire                         sleep,
	input  wire [(WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A)-1:0] wea);

	localparam integer DEPTH       =(MEMORY_SIZE +WRITE_DATA_WIDTH_A -1) /WRITE_DATA_WIDTH_A;
	localparam integer WE_WIDTH    =WRITE_DATA_WIDTH_A /BYTE_WRITE_WIDTH_A;
	localparam integer PIPE_STAGES =(READ_LATENCY_A<=1) ?1 :(READ_LATENCY_A-1);

	reg [WRITE_DATA_WIDTH_A-1:0] mem [0:DEPTH-1];
	reg [READ_DATA_WIDTH_A-1:0] rd_pipe [0:PIPE_STAGES-1];
	reg [WRITE_DATA_WIDTH_A-1:0] old_word;
	reg [WRITE_DATA_WIDTH_A-1:0] new_word;
	reg [READ_DATA_WIDTH_A-1:0]  read_word;

	integer i,p,lane;

	wire any_we;
	assign any_we =|wea;

	assign dbiterra =1'b0;
	assign sbiterra =1'b0;

	initial begin
		for(i=0; i<DEPTH; i=i+1) mem[i] ={WRITE_DATA_WIDTH_A{1'b0}};
		douta ={READ_DATA_WIDTH_A{1'b0}};
		for(p =0; p<PIPE_STAGES; p=p+1) rd_pipe[p] ={READ_DATA_WIDTH_A{1'b0}};

		if(READ_LATENCY_A<1)begin
			$display("ERROR: This simple xpm_memory_spram model supports READ_LATENCY_A >=1 only.");
			$finish;
		end

		if(WRITE_DATA_WIDTH_A !=READ_DATA_WIDTH_A)begin
			$display("WARNING: xpm_memory_spram_sim does not accurately model asymmetric read/write widths.");
			$display("         WRITE_DATA_WIDTH_A =%0d, READ_DATA_WIDTH_A =%0d",
					 WRITE_DATA_WIDTH_A, READ_DATA_WIDTH_A);
		end

		if((WRITE_DATA_WIDTH_A %BYTE_WRITE_WIDTH_A) !=0)begin
			$display("ERROR: WRITE_DATA_WIDTH_A must be divisible by BYTE_WRITE_WIDTH_A.");
			$finish;
		end

		if(USE_MEM_INIT &&
			MEMORY_INIT_FILE !="none" &&
			MEMORY_INIT_FILE !="NONE" &&
			MEMORY_INIT_FILE !="")begin
			$display("xpm_memory_spram_sim: loading memory file: %s", MEMORY_INIT_FILE);
			$readmemh(MEMORY_INIT_FILE, mem);
		end
	end

	always @(posedge clka)begin
		if(rsta)begin
			douta <={READ_DATA_WIDTH_A{1'b0}};
			for (p=0; p<PIPE_STAGES; p=p+1)begin
				rd_pipe[p] <={READ_DATA_WIDTH_A{1'b0}};
			end
		end
		else begin
			if(ena)begin
				if(addra<DEPTH)begin
					old_word =mem[addra];
					new_word =old_word;

					for(lane =0; lane<WE_WIDTH; lane=lane+1)begin
						if(wea[lane])begin
							new_word[lane*BYTE_WRITE_WIDTH_A +:BYTE_WRITE_WIDTH_A]
								=dina[lane*BYTE_WRITE_WIDTH_A +:BYTE_WRITE_WIDTH_A];
						end
					end

					if(any_we) mem[addra] <=new_word;
					
					if(any_we &&
						(WRITE_MODE_A=="write_first" || WRITE_MODE_A=="WRITE_FIRST"))begin
						read_word =new_word;
					end
					else if(any_we &&
						(WRITE_MODE_A=="no_change" || WRITE_MODE_A=="NO_CHANGE"))begin
						read_word =douta;
					end
					else begin
						// Default behavior: read_first
						read_word =old_word;
					end
				end
				else begin
					read_word ={READ_DATA_WIDTH_A{1'bx}};
					if(MESSAGE_CONTROL)begin
						$display("WARNING: xpm_memory_spram_sim address out of range: addra=%0d DEPTH=%0d",
								 addra, DEPTH);
					end
				end

				if(READ_LATENCY_A==1)begin
					if(regcea) douta <=read_word;
				end 
				else begin
					rd_pipe[0] <=read_word;
					for(p=1; p<PIPE_STAGES; p=p+1) rd_pipe[p] <=rd_pipe[p-1];
					if(regcea) douta <=rd_pipe[PIPE_STAGES-1];
				end
			end
		end
	end

endmodule