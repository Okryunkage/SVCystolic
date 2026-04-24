`timescale 1ns/1ps

module fcBRAM#(
	parameter tile     =8,

	parameter inNum    =784,
	parameter outNum   =128,
	parameter inWidth  =8,
	parameter wWidth   =8,
	parameter bWidth   =32,
	parameter accWidth =32,
	parameter inSigned =0,
	parameter wMEMfile ="fc_w.mem",
	parameter bMEMfile ="fc_b.mem")(
	input                                    clk,
	input                                    rst,
	input                                    start,
	input            [(inNum*inWidth-1):0]   inFlat,
	output reg                               busy,
	output reg                               done,
	output reg signed[(outNum*accWidth-1):0] outFlat);

	localparam numTile  =outNum/tile;
	localparam tileIdxW =$clog2(numTile);

	localparam wDepth   =numTile*outNum;
	localparam wAddrW   =$clog2(wDepth);
	localparam bAddrW   =$clog2(numTile);
	localparam inIdxW   =$clog2(inNum);
	localparam outIdxW  =$clog2(numTile);

	localparam[2:0] idle     =3'd0;
	localparam[2:0] biasReq  =3'd1;
	localparam[2:0] biasLoad =3'd2;
	localparam[2:0] wReq     =3'd3;
	localparam[2:0] MAC      =3'd4;
	localparam[2:0] write    =3'd5;

	reg[2:0] state;

	(* ram_style ="block" *) reg signed[(tile*wWidth-1):0] wMEM[0:(wDepth-1)];
	(* ram_style ="block" *) reg signed[(tile*bWidth-1):0] bMEM[0:(numTile-1)];

	reg[(wAddrW-1):0] waddr;
	reg[(bAddrW-1):0] baddr;
	reg signed[(wWidth-1):0] wdata;
	reg signed[(bWidth-1):0] bdata;

	initial begin
		$readmemh(wMEMfile,wMEM);
		$readmemh(bMEMfile,bMEM);
	end

	always@(posedge clk)begin
		wdata <=wMEM[waddr];
		bdata <=bMEM[baddr];
	end

	integer i;

	reg[(inIdxW-1):0]   inIdx;
	reg[(tileIdxW-1):0] tileIdx;
	reg[(wAddrW-1):0]   wbaseAddr;

	reg signed[(accWidth-1):0] acc[0:(tile-1)];

	reg signed[(accWidth-1):0] inExtend;
	reg signed[(accWidth-1):0] wExtend;
	reg signed[(accWidth-1):0] multCut;

	function signed[(accWidth-1):0] inputExtend;
		input[(inWidth-1):0] var;
		begin
			if(inSigned) inputExtend ={{(accWidth-inWidth){var[inWidth-1]}},var};
			else         inputExtend ={{(accWidth-inWidth){1'b0}},var};
		end
	endfunction
	function signed[(wWidth-1):0] weightExtend;
		input[(wWidth-1):0] var;
		begin
			weightExtend ={{(accWidth-wWidth){var[wWidth-1]}},var};
		end
	endfunction
	function signed[(accWidth-1):0] biasExtend;
		input[(bWidth-1):0] var;
		begin
			biasExtend ={{(accWidth-bWidth){var[bWidth-1]}},var};
		end
	endfunction

	always@(posedge clk or posedge rst)begin
		if(rst)begin
			state     <=idle;
			busy      <=1'b0;
			done      <=1'b0;
			outFlat   <={(outNum*accWidth){1'b0}};
			waddr     <={wAddrW{1'b0}};
			baddr     <={bAddrW{1'b0}};			
			wbaseAddr <={wAddrW{1'b0}};
			inIdx     <={inIdxW{1'b0}};
			tileIdx   <={tileIdxW{1'b0}};
			for(i=0;i<tile;i=i+1) acc[k] <={accWidth{1'b0}};
		end
		else begin
			done <=1'b0;
			case(state)
				idle:begin
					if(start)begin
						busy      <=1'b1;
						outFlat   <={(outNum*accWidth){1'b0}};
						tileIdx   <={tileIdxW{1'b0}};
						inIdx     <={inIdxW{1'b0}};
						wbaseAddr <={wAddrW{1'b0}};
						baddr     <={bAddrW{1'b0}};
						state     <=biasReq;
					end
				end
				biasReq: state<=biasLoad;
				biasLoad:begin
					for(i=0;i<tile;i=i+1) acc[i] <=biasExtend(bdata[(i*bWidth)+:bWidth]);
					inIdx <={inIdxW{1'b0}};
					waddr <=wbaseAddr;
					state <=wReq;
				end
				wReq: state <=MAC;
				MAC:begin
					inExtend =inputExtend(inFlat[(inIdx*inWidth)+:inWidth]);
					for(i=0;i<tile;i=i+1)begin
						wExtend  =weightExtend(wdata[(i*wWidth)+:wWidth]);
						multCut =$signed(inExtend*wExtend);
						acc[i] <=acc[i]+multCut;
					end
					if(inIdx==(inNum-1)) state <=write;
					else begin
						inIdx <=inIdx+1'b1;
						waddr <=wbaseAddr+inIdx+1'b1;
						state <=MAC;
					end
				end
				write:begin
					for(i=0;i<tile;i=i+1) outFlat[((tileIdx*tile+i)*accWidth)+:accWidth] <=acc[i];
					if(tileIdx==(numTile-1))begin
						busy  <=1'b0;
						done  <=1'b1;
						state <=idle;
					end
					else begin
						tileIdx   <=tileIdx+1'b1;
						wbaseAddr <=wbaseAddr+inNum;
						baddr     <=tileIdx+1'b1;
						state     <=biasReq;
					end
				end
				default: state <=idle;
			endcase
		end
	end
endmodule
