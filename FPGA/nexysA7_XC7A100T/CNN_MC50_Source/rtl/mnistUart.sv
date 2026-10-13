`timescale 1ns/1ps

//8N1 byte interface. valid/error/done are one clk pulse, not baud-tick levels.
module mnistUart#(parameter int clockHz =100_000_000,baud =115200)(
	input logic clk,rst,rx,
	output wire logic tx,
	output logic[7:0] rxData,
	output logic rxValid,rxError,
	input logic txStart,
	input logic[7:0] txData,
	output logic txBusy,txDone);
	//Fractional baud phase: at100MHz/8Mbps, bit lengths alternate13/12 clocks.
	function automatic integer gcd(input integer a,b);
		integer remainder;
		while(b!=0)begin remainder=a%b; a=b; b=remainder; end
		return a;
	endfunction
	localparam int divisor =gcd(clockHz,baud);
	localparam int clockUnits =2*(clockHz/divisor),baudUnits =2*(baud/divisor);
	localparam int phaseW =$clog2(clockUnits+baudUnits);
	localparam logic[phaseW-1:0] threshold =phaseW'(clockUnits-baudUnits);
	(* ASYNC_REG ="TRUE" *) logic rxMeta =1'b1,rxSync =1'b1;
	typedef enum logic[1:0] {RX_IDLE,RX_START,RX_DATA,RX_STOP} rxStateType;
	rxStateType rxState;
	logic[phaseW-1:0] rxPhase,txPhase;
	wire rxTick =rxPhase>=threshold;
	wire txTick =txPhase>=threshold;
	logic[2:0] rxIndex;
	logic[3:0] txIndex;
	logic[7:0] rxShift;
	logic[9:0] txShift;
	assign tx =txBusy?txShift[0]:1'b1;
	always_ff@(posedge clk)begin
		rxMeta <=rx;
		rxSync <=rxMeta;
	end
	always_ff@(posedge clk)begin
		if(rst)begin
			rxState <=RX_IDLE;
			rxPhase <='0;
			rxIndex <='0;
			rxShift <='0;
			rxData <='0;
			rxValid <=0;
			rxError <=0;
		end
		else begin
			rxValid <=0;
			rxError <=0;
			case(rxState)
				RX_IDLE: if(!rxSync)begin
					rxPhase <=phaseW'(clockUnits/2);
					rxState <=RX_START;
				end
				RX_START: if(!rxTick) rxPhase <=rxPhase+phaseW'(baudUnits);
				else if(rxSync) rxState <=RX_IDLE;
				else begin
					rxIndex <=0;
					rxPhase <=rxPhase-threshold;
					rxState <=RX_DATA;
				end
				RX_DATA: if(!rxTick) rxPhase <=rxPhase+phaseW'(baudUnits);
				else begin
					rxShift[rxIndex] <=rxSync;
					rxPhase <=rxPhase-threshold;
					if(rxIndex==7) rxState <=RX_STOP;
					else rxIndex <=rxIndex+1'b1;
				end
				RX_STOP: if(!rxTick) rxPhase <=rxPhase+phaseW'(baudUnits);
				else begin
					rxData <=rxShift;
					rxValid <=rxSync;
					rxError <=!rxSync;
					rxState <=RX_IDLE;
				end
			endcase
		end
	end
	always_ff@(posedge clk)begin
		if(rst)begin
			txBusy <=0;
			txDone <=0;
			txPhase <=0;
			txIndex <=0;
			txShift <='1;
		end
		else begin
			txDone <=0;
			if(!txBusy)begin
				if(txStart)begin
					txShift <={1'b1,txData,1'b0};
					txPhase <=0;
					txIndex <=0;
					txBusy <=1;
				end
			end
			else if(!txTick) txPhase <=txPhase+phaseW'(baudUnits);
			else if(txIndex==9)begin
				txBusy <=0;
				txDone <=1;
			end
			else begin
				txShift <={1'b1,txShift[9:1]};
				txIndex <=txIndex+1'b1;
				txPhase <=txPhase-threshold;
			end
		end
	end
	`ifndef SYNTHESIS
	initial if(baud<1 || clockHz<1 || clockHz/baud<8) $fatal(1,"Invalid UART clock/baud");
	`endif
endmodule
