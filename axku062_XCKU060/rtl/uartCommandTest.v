`timescale 1ns/1ps

module uartCommandTest#(
	parameter integer boardCLK   =200_000_000,
	parameter integer oversample =20,
	parameter integer baudrate   =1_000_000,
	parameter integer ACCwidth   =24)(
	input  wire clk,
	input  wire rst,
	input  wire uartRX,
	output wire uartTX);

	localparam STATE_RX       =3'd0;
	localparam STATE_TX_LOAD  =3'd1;
	localparam STATE_TX_START =3'd2;
	localparam STATE_TX_WAIT  =3'd3;
	localparam STATE_TX_NEXT  =3'd4;

	reg[2:0] state =STATE_RX;

	reg      TXstart =1'b0;
	reg[7:0] Txitem  =8'h00;

	wire      TXdone;
	wire      TXbusy;
	wire[7:0] RXout;
	wire      RXdone;
	wire      RXbusy;
	wire      RXerror;

	reg[7:0] command   =8'h00;
	reg[4:0] charIndex =5'd0;
	reg[4:0] msgLength =5'd0;

	assign RXbusyLED  =RXbusy;
	assign TXbusyLED  =TXbusy;
	assign RXerrorLED =RXerror;

	uartTOP #(.boardCLK(boardCLK),.oversample(oversample),.baudrate(baudrate),.ACCwidth(ACCwidth))
		UART0(
		.clk(clk),.rst(rst),
		.uartRX(uartRX),.uartTX(uartTX),
		.TXstart(TXstart),.Txitem(Txitem),.TXdone(TXdone),.TXbusy(TXbusy),
		.RXout(RXout),.RXdone(RXdone),.RXbusy(RXbusy),.RXerror(RXerror));

	function[4:0] get_msg_length;
		input[7:0] cmd;
		begin
			case(cmd)
				8'h00: get_msg_length =5'd9;   // "incheon\r\n"
				8'h01: get_msg_length =5'd5;   // "INU\r\n"
				8'h02: get_msg_length =5'd4;   // "EE\r\n"
				8'h03: get_msg_length =5'd5;   // "SVC\r\n"
				8'h04: get_msg_length =5'd6;   // "Lab.\r\n"
				8'h05: get_msg_length =5'd8;   // "master\r\n"
				8'h06: get_msg_length =5'd11;  // "candidate\r\n"
				8'h07: get_msg_length =5'd8;   // "siyeol\r\n"
				8'h08: get_msg_length =5'd5;   // "lee\r\n"
				default: get_msg_length =5'd3; // "?\r\n"
			endcase
		end
	endfunction

	function[7:0] get_msg_char;
		input[7:0] cmd;
		input[4:0] idx;
		begin
			get_msg_char = 8'h00;
			case(cmd)
				8'h00: begin
					case(idx)
						5'd0: get_msg_char ="i";
						5'd1: get_msg_char ="n";
						5'd2: get_msg_char ="c";
						5'd3: get_msg_char ="h";
						5'd4: get_msg_char ="e";
						5'd5: get_msg_char ="o";
						5'd6: get_msg_char ="n";
						5'd7: get_msg_char =8'h0D;
						5'd8: get_msg_char =8'h0A;
					endcase
				end
				8'h01: begin
					case(idx)
						5'd0: get_msg_char ="I";
						5'd1: get_msg_char ="N";
						5'd2: get_msg_char ="U";
						5'd3: get_msg_char =8'h0D;
						5'd4: get_msg_char =8'h0A;
					endcase
				end
				8'h02: begin
					case(idx)
						5'd0: get_msg_char ="E";
						5'd1: get_msg_char ="E";
						5'd2: get_msg_char =8'h0D;
						5'd3: get_msg_char =8'h0A;
					endcase
				end
				8'h03: begin
					case(idx)
						5'd0: get_msg_char ="S";
						5'd1: get_msg_char ="V";
						5'd2: get_msg_char ="C";
						5'd3: get_msg_char =8'h0D;
						5'd4: get_msg_char =8'h0A;
					endcase
				end
				8'h04: begin
					case(idx)
						5'd0: get_msg_char ="L";
						5'd1: get_msg_char ="a";
						5'd2: get_msg_char ="b";
						5'd3: get_msg_char =".";
						5'd4: get_msg_char =8'h0D;
						5'd5: get_msg_char =8'h0A;
					endcase
				end
				8'h05: begin
					case(idx)
						5'd0: get_msg_char ="m";
						5'd1: get_msg_char ="a";
						5'd2: get_msg_char ="s";
						5'd3: get_msg_char ="t";
						5'd4: get_msg_char ="e";
						5'd5: get_msg_char ="r";
						5'd6: get_msg_char =8'h0D;
						5'd7: get_msg_char =8'h0A;
					endcase
				end
				8'h06: begin
					case(idx)
						5'd0: get_msg_char ="c";
						5'd1: get_msg_char ="a";
						5'd2: get_msg_char ="n";
						5'd3: get_msg_char ="d";
						5'd4: get_msg_char ="i";
						5'd5: get_msg_char ="d";
						5'd6: get_msg_char ="a";
						5'd7: get_msg_char ="t";
						5'd8: get_msg_char ="e";
						5'd9: get_msg_char =8'h0D;
						5'd10:get_msg_char =8'h0A;
					endcase
				end
				8'h07: begin
					case(idx)
						5'd0: get_msg_char ="s";
						5'd1: get_msg_char ="i";
						5'd2: get_msg_char ="y";
						5'd3: get_msg_char ="e";
						5'd4: get_msg_char ="o";
						5'd5: get_msg_char ="l";
						5'd6: get_msg_char =8'h0D;
						5'd7: get_msg_char =8'h0A;
					endcase
				end
				8'h08: begin
					case(idx)
						5'd0: get_msg_char ="l";
						5'd1: get_msg_char ="e";
						5'd2: get_msg_char ="e";
						5'd3: get_msg_char =8'h0D;
						5'd4: get_msg_char =8'h0A;
					endcase
				end
				default: begin
					case(idx)
						5'd0: get_msg_char ="?";
						5'd1: get_msg_char =8'h0D;
						5'd2: get_msg_char =8'h0A;
					endcase
				end
			endcase
		end
	endfunction

	always@(posedge clk)begin
		if(rst)begin
			state     <=STATE_RX;
			TXstart   <=1'b0;
			Txitem    <=8'h00;
			command   <=8'h00;
			charIndex <=5'd0;
			msgLength <=5'd0;
		end
		else begin
			case(state)
				STATE_RX: begin
					TXstart <=1'b0;
					if(RXdone) begin
						command   <=RXout;
						msgLength <=get_msg_length(RXout);
						charIndex <=5'd0;
						state     <=STATE_TX_LOAD;
					end
				end
				STATE_TX_LOAD: begin
					TXstart <=1'b0;
					Txitem  <=get_msg_char(command,charIndex);
					state   <=STATE_TX_START;
				end
				STATE_TX_START: begin
					TXstart <=1'b1;
					if(TXbusy)begin
						TXstart <=1'b0;
						state   <=STATE_TX_WAIT;
					end
				end
				STATE_TX_WAIT: begin
					TXstart <=1'b0;
					if(TXdone) state <= STATE_TX_NEXT;
				end
				STATE_TX_NEXT: begin
					TXstart <=1'b0;
					if(charIndex==(msgLength-1'b1))begin
						charIndex <=5'd0;
						state     <=STATE_RX;
					end
					else begin
						charIndex <=(charIndex+1'b1);
						state     <=STATE_TX_LOAD;
					end
				end
				default: state <=STATE_RX;
			endcase
		end
	end
endmodule