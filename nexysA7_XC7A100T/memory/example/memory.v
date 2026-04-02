`timescale 1ps/1ps

module memory(
	input            sys_clk_i,
	input			 sys_rst,
	//User Address, Command, Enable Signal
	input  [26:0]    app_addr,
	input  [2:0]     app_cmd,
	input            app_en,
	//wriet data FIFO
	input  [63:0]    app_wdf_data,
	//Write Data Final bit Signal
	input            app_wdf_end,
	//Byte Write Mask. Active-Low
	input  [7:0]     app_wdf_mask,
	//Valid Signal
	input            app_wdf_wren,
	//app_sr_req is reserved to 0
	input            app_sr_req,
	//refresh Request Signal. Active-high
	//MIG will automatically refresh the DRAM,
	input            app_ref_req,
	//ZQ calibartion
	input            app_zq_req,
	//Data Line
	inout  [15:0]    ddr2_dq,
	inout  [1:0]     ddr2_dqs_n,
	inout  [1:0]     ddr2_dqs_p,
	//Memory Address & Bank Address
	output [12:0]    ddr2_addr,
	output [2:0]     ddr2_ba,
	//Memory Command
	output           ddr2_ras_n,
	output           ddr2_cas_n,
	output           ddr2_we_n,
	//Memory CLK
	output [0:0]     ddr2_ck_p,
	output [0:0]     ddr2_ck_n,
	output [0:0]     ddr2_cke,
	//Chip Select
	output [0:0]     ddr2_cs_n,
	//Data Mask
	output [1:0]     ddr2_dm,
	//On-Die Termination
	output [0:0]     ddr2_odt,
	//Read Data
	output [63:0]    app_rd_data,
	//Read Data End
	output           app_rd_data_end,
	output           app_rd_data_valid,
	//MIG ready
	output           app_rdy,
	//MIG write data FIFO ready
	output           app_wdf_rdy,
	//reserved signal
	output           app_sr_active,
	//refresh <= ignore
	output           app_ref_ack,
	//ignore this too
	output           app_zq_ack,
	//User CLK output
	output           ui_clk,
	output           ui_clk_sync_rst,
	//Calibration Complete Signal
	output           init_calib_complete
);
  memory_mig u_memory_mig (
	.ddr2_addr                      (ddr2_addr),
	.ddr2_ba                        (ddr2_ba),
	.ddr2_cas_n                     (ddr2_cas_n),
	.ddr2_ck_n                      (ddr2_ck_n),
	.ddr2_ck_p                      (ddr2_ck_p),
	.ddr2_cke                       (ddr2_cke),
	.ddr2_ras_n                     (ddr2_ras_n),
	.ddr2_we_n                      (ddr2_we_n),
	.ddr2_dq                        (ddr2_dq),
	.ddr2_dqs_n                     (ddr2_dqs_n),
	.ddr2_dqs_p                     (ddr2_dqs_p),
	.init_calib_complete            (init_calib_complete),
	.ddr2_cs_n                      (ddr2_cs_n),
	.ddr2_dm                        (ddr2_dm),
	.ddr2_odt                       (ddr2_odt),
	.app_addr                       (app_addr),
	.app_cmd                        (app_cmd),
	.app_en                         (app_en),
	.app_wdf_data                   (app_wdf_data),
	.app_wdf_end                    (app_wdf_end),
	.app_wdf_wren                   (app_wdf_wren),
	.app_rd_data                    (app_rd_data),
	.app_rd_data_end                (app_rd_data_end),
	.app_rd_data_valid              (app_rd_data_valid),
	.app_rdy                        (app_rdy),
	.app_wdf_rdy                    (app_wdf_rdy),
	.app_sr_req                     (app_sr_req),
	.app_ref_req                    (app_ref_req),
	.app_zq_req                     (app_zq_req),
	.app_sr_active                  (app_sr_active),
	.app_ref_ack                    (app_ref_ack),
	.app_zq_ack                     (app_zq_ack),
	.ui_clk                         (ui_clk),
	.ui_clk_sync_rst                (ui_clk_sync_rst),
	.app_wdf_mask                   (app_wdf_mask),
	.sys_clk_i                       (sys_clk_i),
	.sys_rst                        (sys_rst)
    );
endmodule