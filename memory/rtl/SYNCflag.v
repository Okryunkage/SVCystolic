`timescale 1ns/1ps

module SYNCflag(
	input aRST,
	input aCLK,
	input aFLAG,
	input bRST,
	input bCLK,
	output bFLAG
);
	reg flag;
	always@(posedge aCLK or posedge aRST)begin
		if(aRST) flag <=0;
		else flag <=flag^aFLAG;
	end
	(* ASYNC_REG = "TRUE" *) reg[2:0] SYNCflag;
	always@(posedge bCLK or posedge bRST)begin
		if(bRST) SYNCflag <=3'h0;
		else SYNCflag <={SYNCflag[1:0], flag};
	end
	assign bFLAG =(SYNCflag[1]^SYNCflag[2]);
endmodule