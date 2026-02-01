`include "adder.v"
`include "tree.v"
`include "multiplier.v"
`include "accumulator.v"
`include "pe.v"
`include "proposed_bka.v"
`include "register.v"
`include "inout_reg.v"
`include "bka.v"
`include "proposed_IOr.v"
`timescale 1ns/1ps

module tb_proposed;
	localparam size=16;
	localparam in_width=16;
	localparam out_width=16;
	localparam bussize=size+16;
	localparam busize=bussize-1;
	reg clk,preclk,in_clk,out_clk;
	reg [(size*8/in_width-1):0] en_in;
	reg en_out;
	reg [(size*8/in_width-1):0] data_in;
	wire [(bussize/out_width*size-1):0] data_out;
	reg [(8*size*size-1):0] weight, in;
	reg [(8*size-1):0] weight_in, in_in;
	proposed_IOr #(size,in_width,out_width) pe0(clk,preclk,out_clk,out_clk,
				en_in,en_out,data_in,data_out);
	//--------------------
	genvar c,d;
	/*
	generate
		for(c=0;c<size;c=c+1)begin:weight_col
			for(d=0;d<size;d=d+1)begin:weight_row
				wire [7:0] weight8;
				assign weight8 =weight[((8*size*c)+8*(d+1)-1)-:8];
			end
		end
	endgenerate
	*/
	generate
		for(c=0;c<size;c=c+1)begin:in_col
			for(d=0;d<size;d=d+1)begin:in_row
				wire [7:0] in8;
				assign in8 =in[((8*size*c)+8*(d+1)-1)-:8];
			end
		end
	endgenerate
	/*
	generate
		for(c=0;c<size;c=c+1)begin:weight_in_col
			wire [7:0] weight_in8;
			assign weight_in8 =weight_in[8*c+:8];
		end
	endgenerate
	generate
		for(c=0;c<size;c=c+1)begin:in_in_col
			wire [7:0] in_in8;
			assign in_in8 =in_in[8*c+:8];
		end
	endgenerate
	generate
		for(c=0;c<size;c=c+1)begin:result_col
			wire [busize:0] result8;
			assign result8 =result[bussize*c+:bussize];
		end
	endgenerate
	*/
	//--------------------
	task weight_upshift(
		input integer i,
		inout [(8*size-1):0] weightbuff);
		integer sh;
		reg [(8*size-1):0] temp;
		begin
			sh =8*i;
			if(sh==0) temp=weightbuff;
			else temp = (weightbuff>>sh)|(weightbuff<<(8*size-sh));
			weightbuff=temp;
		end
	endtask
	task weight_exchange(
		input integer i,
		inout [(8*size-1):0] weightbuff);
		integer j;
		reg [(8*size-1):0] temp;
		begin
			for(j=0;j<i;j=j+1)begin
				if((j%2)==0) temp[j*8+:8]=weightbuff[j*8+:8];
				else temp[j*8+:8]=weightbuff[((j+i/2)%i)*8+:8];
			end
			weightbuff=temp;
		end
	endtask
	//------------------------------
	initial begin
		en_in = {size{1'b0}};
		en_out = 1'b0;
	end
	localparam real period=1.0; //real number
	localparam real clk_period=period*16.0;
	localparam real in_period=period*2.0;
	initial out_clk=1'b1;
	always #(period/2.0) out_clk=~out_clk; //# means delay (@ means event triggered)	
	initial begin
		in_clk = 1'b1;
		clk = 1'b1;
		preclk = 1'b0;
	end
	reg [1:0] div4;
	reg [3:0] div16;
	initial begin
		div4=2'd0;
		div16=4'd0;
	end
	always @(posedge out_clk)begin
		in_clk<=~in_clk;
		div16<=div16+4'd1;
		if(div16==4'd15) div16<=4'd0;
	end
	always @(posedge in_clk)begin 
		div4<=div4+2'd1;
		if(div4==2'd3)begin
			div4<=2'd0;
			clk <=~clk;
		end
	end
	reg en_out_clk;
	initial en_out_clk = 1'b0;
	always #((period/2.0)-0.1)begin
		en_out_clk=~en_out_clk;
		if(div16==4'hF) en_out=en_out_clk;
		else en_out =1'b0;
	end
	//------------------------------
	//...[X_31][X_21][X_11][X_01][X_30][X_20][X_10][X_00]
	integer a,b;
	integer ww =0;
	integer ii =0;
	integer i,j,k;
	integer l;
	integer m,n;
	initial begin
		$dumpfile("out.vcd");
		$dumpvars(0,tb_proposed);
		for(a=0;a<size;a=a+1)begin
			for(b=0;b<size;b=b+1)begin
				ww = ww+1;
				ii = ii-1;
				weight[((8*size*b)+8*(a+1)-1)-:8] =ww;
				in    [((8*size*b)+8*(a+1)-1)-:8] =ii;
			end
		end
		#clk_period;
		for(i=0;i<size;i=i+1)begin
			weight_upshift(i,weight[(8*size*(i+1)-1)-:8*size]);
		end
		#clk_period;
		for(i=0;i<size;i=i+1)begin
			weight_exchange(size,weight[(8*size*(i+1)-1)-:8*size]);
		end
		#clk_period;
		//weight_preload
		for(i=0;i<size;i=i+1)begin:row
			for(l=1;l>=0;l=l-1)begin
				for(k=7;k>=0;k=k-1)begin:bitwise
					for(j=0;j<(size*8/in_width);j=j+1)begin
						m=(8*size*(2*j+l)+8*(size-i-1));
						n=m+k;
						data_in[j] =weight[8*size*(2*j+l)+8*(size-i-1)+k];
					end
					#period; preclk=1'b0;
				end
			end
			preclk=1'b1;
		end
		#period;
		preclk=1'b0;
		#(clk_period-period+0.01);
		for(i=0;i<size;i=i+1)begin
			for(l=1;l>=0;l=l-1)begin
				for(k=7;k>=0;k=k-1)begin
					for(j=0;j<(size*8/in_width);j=j+1)begin
						m=(8*size*(2*j+l)+8*i);
						n=m+k;
						data_in[j] =in[8*size*(2*j+l)+8*i+k];
						//#(period/8);
					end
					#period;
				end
			end
		end		
		#512;
		$finish;
	end
endmodule
