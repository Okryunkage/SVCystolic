`timescale 1ns/1ps

//FC with overlapped input/weight BRAM reads, operand capture, and MAC.
//Both responses must arrive after exactly two clocks; there is no backpressure.
//The reader maps logical channel-major indices to packed feature-map words.
module fcCore#(
	parameter int tile =5,inNum =784,outNum =10,
	parameter int dataWidth =8,wWidth =8,bWidth =8,accWidth =32,
	parameter int biasShift =0,
	parameter bit inSigned =1'b0,
	parameter int numTile =(outNum+tile-1)/tile,
	parameter int wDepth =numTile*inNum,
	parameter int wAddrW =(wDepth>1)?$clog2(wDepth):1,
	parameter int bAddrW =(numTile>1)?$clog2(numTile):1,
	parameter int indexW =(inNum>1)?$clog2(inNum):1)(
	input logic clk,rst,start,
	output wire logic requestEnable,
	output wire logic[indexW-1:0] requestIndex,
	input logic inValid,
	input logic[dataWidth-1:0] inData[0:0],
	input logic signed[tile-1:0][wWidth-1:0] wdata,
	input logic signed[tile-1:0][bWidth-1:0] bdata,
	output logic[wAddrW-1:0] waddr,
	output logic[bAddrW-1:0] baddr,
	output logic busy,done,
	output logic signed[accWidth-1:0] outData[0:outNum-1]);

	localparam int tileW =(numTile>1)?$clog2(numTile):1;
	localparam int productWidth =dataWidth+1+wWidth;
	typedef enum logic[3:0] {IDLE,BIAS_REQ,BIAS_WAIT0,BIAS_WAIT1,BIAS_LOAD,
		W_RUN,WRITE_RESULT,FINISH} stateType;
	stateType state;
	logic[indexW-1:0] issueIdx,consumeIdx;
	logic[tileW-1:0] tileIndex;
	logic[wAddrW-1:0] wbaseAddr;
	logic[1:0] wvalid;
	logic issueDone;
	logic macValid,macLast;
	logic[dataWidth-1:0] inputRegister;
	logic signed[tile-1:0][wWidth-1:0] weightRegister;
	logic signed[accWidth-1:0] accumulator[0:tile-1];
	//One extra input bit preserves unsigned activations in a signed multiply.
	logic signed[dataWidth:0] inputValue;
	logic signed[wWidth-1:0] weightValue;
	logic signed[productWidth-1:0] product;
	logic signed[accWidth-1:0] productExtend;

	assign requestEnable =state==W_RUN && !issueDone && !rst;
	assign requestIndex =issueIdx;
	always_comb begin
		waddr =wbaseAddr+wAddrW'(issueIdx);
		baddr =bAddrW'(tileIndex);
	end
	always_ff@(posedge clk)begin
		if(rst)begin
			state <=IDLE;
			busy <=0;
			done <=0;
			issueIdx <='0;
			consumeIdx <='0;
			tileIndex <='0;
			wbaseAddr <='0;
			wvalid <=2'b00;
			issueDone <=0;
			{macValid,macLast} <='0;
			inputRegister <='0;
			weightRegister <='0;
			for(integer l =0;l<tile;l =l+1) accumulator[l] <='0;
			for(integer n =0;n<outNum;n =n+1) outData[n] <='0;
		end
		else begin
			done <=0;
			macValid <=0;
			case(state)
				IDLE: if(start)begin
					busy <=1;
					issueIdx <='0;
					consumeIdx <='0;
					tileIndex <='0;
					wbaseAddr <='0;
					wvalid <=2'b00;
					issueDone <=0;
					{macValid,macLast} <='0;
					state <=BIAS_REQ;
				end
				BIAS_REQ: state <=BIAS_WAIT0;
				BIAS_WAIT0: state <=BIAS_WAIT1;
				BIAS_WAIT1: state <=BIAS_LOAD;
				BIAS_LOAD:begin
					for(integer l =0;l<tile;l =l+1)
						accumulator[l] <=$signed({{(accWidth-bWidth){bdata[l][bWidth-1]}},bdata[l]}) <<< biasShift;
					issueIdx <='0;
					consumeIdx <='0;
					wvalid <=2'b00;
					issueDone <=0;
					state <=W_RUN;
				end
				W_RUN:begin
					//Request one weight word per clock and track its two-clock response.
					wvalid <={wvalid[0],!issueDone};
					if(!issueDone)begin
						if(issueIdx==inNum-1) issueDone <=1;
						else issueIdx <=issueIdx+1'b1;
					end
					if(wvalid[1])begin
						//Capture aligned BRAM operands before the multiply/add path.
						inputRegister <=inData[0];
						weightRegister <=wdata;
						macValid <=1;
						macLast <=consumeIdx==inNum-1;
						if(consumeIdx==inNum-1) wvalid <=2'b00;
						else consumeIdx <=consumeIdx+1'b1;
					end
					if(macValid)begin
						if(inSigned)
							inputValue =$signed({inputRegister[dataWidth-1],inputRegister});
						else
							inputValue =$signed({1'b0,inputRegister});
						for(integer l =0;l<tile;l =l+1)begin
							weightValue =$signed(weightRegister[l]);
							product =inputValue*weightValue;
							//Resize the signed product only AFTER the narrow multiply.
							//A narrower accWidth retains the prior modulo arithmetic.
							productExtend =accWidth'(product);
							accumulator[l] <=accumulator[l]+productExtend;
						end
						//Drain the final MAC, not merely the final memory response.
						if(macLast) state <=WRITE_RESULT;
					end
				end
				WRITE_RESULT:begin
					for(integer l =0;l<tile;l =l+1)
						if(int'(tileIndex)*tile+l<outNum)
							outData[int'(tileIndex)*tile+l] <=accumulator[l];
					if(tileIndex==numTile-1) state <=FINISH;
					else begin
						tileIndex <=tileIndex+1'b1;
						wbaseAddr <=wbaseAddr+wAddrW'(inNum);
						state <=BIAS_REQ;
					end
				end
				FINISH:begin
					busy <=0;
					done <=1;
					state <=IDLE;
				end
				default: state <=IDLE;
			endcase
		end
	end
	`ifndef SYNTHESIS
	always@(posedge clk)
		if(!rst && state==W_RUN && wvalid[1] && inValid!==1'b1)
			$fatal(1,"fcCore requires a reader response exactly two clocks after each request");
	initial begin
		if(tile<1 || outNum<1 || inNum<1 ||
			accWidth<dataWidth+1 || accWidth<bWidth || accWidth<wWidth ||
			biasShift<0 || bWidth+biasShift>accWidth)
			$fatal(1,"Invalid fcCore parameters");
	end
	`endif
endmodule
