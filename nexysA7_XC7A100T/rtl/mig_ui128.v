`timescale 1ns/1ps

//Signal Description can be found on </nexysA7_XC7A100T/memory/readme>
module mig_ui128(
	input migclk,
	input rst_n,

	input wire       boardclk,
	input wire[26:0] addr,
	input wire[1:0]  width,
	input wire[127:0] data_in,
	output reg[127:0] data_out,
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
	output[0:0] ddr2_odt,

	output wire mem_rdy
);

	wire ui_clk, ui_clk_sync_rst;
	reg[2:0] mem_cmd;
	reg mem_en;
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
		.aRST(~rst_n),
		.aCLK(boardclk),
		.aFLAG(rstrobe),
		.bRST(ui_clk_sync_rst),
		.bCLK(ui_clk),
		.bFLAG(rstrobe_sync));

	SYNCflag SYNCws(
		.aRST(~rst_n),
		.aCLK(boardclk),
		.aFLAG(wstrobe),
		.bRST(ui_clk_sync_rst),
		.bCLK(ui_clk),
		.bFLAG(wstrobe_sync));

	reg complete;

	SYNCflag SYNCcomplete(
		.aRST(ui_clk_sync_rst),
		.aCLK(ui_clk),
		.aFLAG(complete),
		.bRST(~rst_n),
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

	always@(posedge ui_clk)begin
		if(ui_clk_sync_rst) data_out <=64'h0;
		else begin
			if(((state==stateREAD)&&(mem_rd_data_valid))||((state==statePREREAD)&&(mem_rdy)&&(mem_rd_data_valid)))begin
				//when (data is available normally)or(data available right after the command accepted)
				if(~mem_rd_data_end) data_out[63:0] <=mem_rd_data[63:0];
				else data_out[127:64] <=mem_rd_data[63:0];
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
						mem_wdf_mask <=8'h00;
						mem_wdf_data <=data_in[63:0];
					end
					mem_wdf_wren <=1'b1;
					state <=stateWDL;
				end

				stateWDL:begin
					if(mem_wdf_rdy)begin
							mem_wdf_mask <=8'h00;
							mem_wdf_data <=data_in[127:64];
					end
					mem_wdf_wren <=1'b1;
					mem_wdf_end <=1'b1;
					complete <=1'b1;
					state <=stateIDLE;
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