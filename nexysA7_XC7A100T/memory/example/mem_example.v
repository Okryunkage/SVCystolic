`timescale 1ns/1ps

//The same module in </nexysA7_XC7A100T/rtl/0etc/mig_ui.v>
//Signal Description can be found on </nexysA7_XC7A100T/memory/readme>
module memEx(
	input migclk,
	input rst_n,

	input wire       boardclk,
	input wire[27:0] addr,
	input wire[1:0]  width,
	input wire[63:0] data_in,
	output reg[63:0] data_out,
	input wire       rstrobe,
	input wire       wstrobe,
	output wire      transaction_complete,
	output           ready,

	inout[15:0]  ddr2_dq,
	inout[1:0]   ddr2_dqs_n,
	inout[1:0]   ddr2_dqs_p,
	output[12:0] ddr2_addr,
	output[2:0] ddr2_ba,
	output ddr2_ras_n,
	output ddr2_cas_n,
	output ddr2_we_n,
	output[0:0] ddr2_ck_p,
	output[0:0] ddr2_ck_n,
	output[0:0] ddr2_cke,
	output[0:0] ddr2_cs_n,
	output[1:0] ddr2_dm,
	output[0:0] ddr2_odt
);

	wire ui_clk, ui_clk_sync_rst;
	reg[2:0] mem_cmd;
	reg mem_en;
	wire mem_rdy;
	wire mem_rd_data_end, mem_rd_data_valid;
	wire[63:0] mem_rd_data;
	reg[63:0] mem_wdf_data;
	reg mem_wdf_end, mem_wdf_wren;
	reg[7:0] mem_wdf_mask;
	wire mem_wdf_rdy;

	memory mem(
		.sys_clk_i(migclk), .sys_rst(rst_n), .app_addr(addr[27:0]), .app_cmd(mem_cmd), .app_en(mem_en),
		.init_calib_complete(), .ui_clk(ui_clk), .ui_clk_sync_rst(ui_clk_sync_rst), .app_rdy(mem_rdy),
		.app_rd_data(mem_rd_data), .app_rd_data_end(mem_rd_data_end), .app_rd_data_valid(mem_rd_data_valid),
		.app_wdf_data(mem_wdf_data), .app_wdf_mask(mem_wdf_mask), .app_wdf_wren(mem_wdf_wren), .app_wdf_end(mem_wdf_end),
		.app_wdf_rdy(mem_wdf_rdy),

		.app_sr_req(1'b0), .app_ref_req(1'b0), .app_zq_req(1'b0),
		.app_sr_active(), .app_ref_ack(), .app_zq_ack(),
		.ddr2_dq(ddr2_dq), .ddr2_dqs_n(ddr2_dqs_n), .ddr2_dqs_p(ddr2_dqs_p), .ddr2_addr(ddr2_addr),
		.ddr2_ba(ddr2_ba), .ddr2_ras_n(ddr2_ras_n), .ddr2_cas_n(ddr2_cas_n), .ddr2_we_n(ddr2_we_n),
		.ddr2_ck_n(ddr2_ck_n), .ddr2_ck_p(ddr2_ck_p), .ddr2_cke(ddr2_cke), .ddr2_cs_n(ddr2_cs_n),
		.ddr2_dm(ddr2_dm), .ddr2_odt(ddr2_odt));
	
	wire rstrobe_sync, wstrobe_sync;

	SYNCflag SYNCrs(
		.aRST(rst_n),
		.aCLK(boardclk),
		.aFLAG(rstrobe),
		.bRST(~ui_clk_sync_rst),
		.bCLK(ui_clk),
		.bFLAG(rstrobe_sync));

	SYNCflag SYNCws(
		.aRST(rst_n),
		.aCLK(boardclk),
		.aFLAG(wstrobe),
		.bRST(~ui_clk_sync_rst),
		.bCLK(ui_clk),
		.bFLAG(wstrobe_sync));

	reg complete;

	SYNCflag SYNCcomplete(
		.aRST(~ui_clk_sync_rst),
		.aCLK(ui_clk),
		.aFLAG(complete),
		.bRST(rst_n),
		.bCLK(boardclk),
		.bFLAG(transaction_complete));

	//Original contributer utilized ui_clk_sync_rst for ready signal instead of init_calib_complete
	//the AMD document stated "“application has no need to wait for init_calib_complete before sending commands to the Memory Controller"
	//init_calib_complete: DDR initialize & Calibration Done
	//ui_clk_sync_rst: MIG UI clock domain reset signal.
	//app_rdy: ...
	SYNCff SYNCready(
		.clk(boardclk),
		.rst(~rst_n),
		.in(~ui_clk_sync_rst),
		.out(ready)
	);

	reg[2:0] state;
	localparam stateIDLE    =3'h0;
	localparam statePREREAD =3'h1;
	localparam stateREAD    =3'h2;
	localparam stateWRITE   =3'h3;
	localparam stateWDH     =3'h4;
	localparam stateWDL     =3'h5;

	localparam CMDread      =3'h1;
	localparam CMDwrite     =3'h0;

	localparam RAMw64       =2'h0;
	localparam RAMw32       =2'h1;
	localparam RAMw16       =2'h2;
	localparam RAMw8        =2'h3;

	//According to the AMD document U586, some lowe address bits are ignored depending on the width of the memory array.
	//This is because the MIG user interface handles data in DDR burst units, and the controller follows burst ordering,
	//which results in a minimum valid step size for app_addr by ignoring the low-order eaddress bits.
	//As a result, for a 16-bit memory bus, data is read in 2-byte units, so address[0] is ignored and treated as 0.
	//Therefore, odd-address information cannot be obtained directly by simply providing an odd address to MIG.
	//Instead, the controller returns aligned read data, and the user logic must reconstruct the requested value manually.
	//In the case of desired 64-bit data starts at an odd byte address on our configuration, the requried bytes may span two read beats.
	//Thus, the logic must take part of the data from the first beat and the reamining part from the next beat.

	always@(posedge ui_clk)begin
		if(ui_clk_sync_rst) data_out <=64'h0;
		else begin
			if(((state==stateREAD)&&(mem_rd_data_valid))||((state==statePREREAD)&&(mem_rdy)&&(mem_rd_data_valid)))begin
				//when (data is available normally)or(data available right after the command accepted)
				if(~addr[0])begin
					if(~mem_rd_data_end)begin
						case(width)
						//Rearrange the MIG read data before stroing it in data_out.
						//Lower-address bytes go to the upper bits,
						//and higher-address bytes go to the lower bits of data_out.
							RAMw64: data_out <={mem_rd_data[7:0],mem_rd_data[15:8],
												mem_rd_data[23:16],mem_rd_data[31:24],
												mem_rd_data[39:32],mem_rd_data[47:40],
												mem_rd_data[55:48],mem_rd_data[63:56]};		
							RAMw32: data_out <={mem_rd_data[7:0],mem_rd_data[15:8],
												mem_rd_data[23:16],mem_rd_data[31:24],32'h0};
							RAMw16: data_out <={mem_rd_data[7:0],mem_rd_data[15:8],48'h0};
							RAMw8:  data_out <={mem_rd_data[7:0],56'h0};
						endcase
					end
				end
				else begin
					if(mem_rd_data_end)begin
						if(width==RAMw64) data_out[7:0] <=mem_rd_data[7:0];
					end
					else begin
						case(width)
							RAMw64: data_out[63:8] <={mem_rd_data[15:8],mem_rd_data[23:16],
													  mem_rd_data[31:24],mem_rd_data[39:32],
													  mem_rd_data[47:40],mem_rd_data[55:48],mem_rd_data[63:56]};
							RAMw32: data_out[63:0] <={mem_rd_data[15:8],mem_rd_data[23:16],
													  mem_rd_data[31:24],mem_rd_data[39:32],32'h0};
							RAMw16: data_out[63:0] <={mem_rd_data[15:8],mem_rd_data[23:16],48'h0};
							RAMw8 : data_out[63:0] <={mem_rd_data[15:8],56'h0};
						endcase
					end
				end
			end
		end
	end

	always@(posedge ui_clk)begin
		if(ui_clk_sync_rst)begin
			state <=stateIDLE;
			complete <=0;
			mem_cmd <=CMDwrite;
			mem_wdf_mask <=8'h00;
			mem_wdf_data <=64'h0;
			mem_wdf_wren <=1'b0;
			mem_wdf_end <=1'b0;
			mem_en <=1'b0;
		end
		else begin
			complete <=1'b0;

			case(state)
				stateIDLE:begin
					mem_wdf_wren <=1'b0;
					if(wstrobe_sync)begin
						mem_en <=1'b1;
						mem_cmd <=CMDwrite;
						mem_wdf_end <=1'b0;
						state <=stateWRITE;
					end
					else if(rstrobe_sync)begin
						mem_en <=1'b1;
						mem_cmd <=CMDread;
						state <=statePREREAD;
					end
				end

				stateWDH:begin
					if(mem_wdf_rdy)begin
						if(~addr[0])begin
							case(width)
							//When think of writing 64'h1122334455667788 to address A to (A+7),
							//The default writing configuration will write 8'h11 in address (A+7)
							//However, since reading operation reverse the Byte order as written above, 
							//the data would appear in LSB Byte of data_out register.
							//Resulting data_out to be 64'h8877665544332211.
							//Thus, to match read and write operation, write Byte orientation should be reversed as same as read opration
								RAMw64:begin
									mem_wdf_mask <=8'h00;
									mem_wdf_data <={data_in[7:0],data_in[15:8],data_in[23:16],data_in[31:24],
													data_in[39:32],data_in[47:40],data_in[55:48],data_in[63:56]};
								end
								RAMw32:begin
									mem_wdf_mask <=8'hF0; //1111_0000
									mem_wdf_data <={32'h0,data_in[7:0],data_in[15:8],data_in[23:16],data_in[31:24]};
								end
								RAMw16:begin
									mem_wdf_mask <=8'hFC; //1111_1100
									mem_wdf_data <={48'h0,data_in[7:0],data_in[15:8]};
								end
								RAMw8:begin
									mem_wdf_mask <=8'hFE; //1111_1110
									mem_wdf_data<={56'h0,data_in[7:0]};
								end
							endcase
						end
						else begin
							case(width)
								RAMw64:begin
									mem_wdf_mask <=8'h01; //0000_0001
									mem_wdf_data <={data_in[15:8],data_in[23:16],data_in[31:24],data_in[39:32],
													data_in[47:40],data_in[55:48],data_in[63:56],8'h0};
								end
								RAMw32:begin
									mem_wdf_mask <=8'hE1; //1110_0001
									mem_wdf_data <={24'h0,data_in[7:0],data_in[15:8],data_in[23:16],data_in[31:24],8'h0};
								end
								RAMw16:begin
									mem_wdf_mask <=8'hF9; //1111_1001
									mem_wdf_data <={40'h0,data_in[7:0],data_in[15:8],8'h0};
								end
								RAMw8:begin
									mem_wdf_mask <=8'hFD; //1111_1101
									mem_wdf_data <={48'h0,data_in[7:0],8'h0};
								end
							endcase
						end
						mem_wdf_wren <=1'b1;
						state <=stateWDL;
					end
				end

				stateWDL:begin
					if(mem_wdf_rdy)begin
						if(~addr[0])begin
							mem_wdf_mask <=8'hFF;
							mem_wdf_data <=64'h0;
						end
						else begin
							//I followed the original example,
							//but it seems this writing only needed when its RAMw64
							mem_wdf_mask <=8'hFE; //1111_1110
							mem_wdf_data <={56'h0,data_in[7:0]};
						end
						mem_wdf_wren <=1'b1;
						mem_wdf_end <=1'b1;
						complete <=1'b1;
						state <=stateIDLE;
					end
				end

				statePREREAD:begin
					if(mem_rdy)begin
						mem_en <=1'b0;
						state <=stateREAD;
						if(mem_rd_data_valid&mem_rd_data_end)begin
							state <=stateIDLE;
							complete <=1'b1;
						end
					end
				end

				stateREAD:begin
					if(mem_rd_data_valid&mem_rd_data_end)begin
						state <=stateIDLE;
						complete <=1'b1;
					end
				end

				stateWRITE:begin
					if(mem_rdy)begin
						mem_en <=1'b0;
						state <=stateWDH;
					end
				end
			endcase
		end
	end
endmodule