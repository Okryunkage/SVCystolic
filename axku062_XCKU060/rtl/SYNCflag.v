`timescale 1ns/1ps

/*
******************************
***      Flag Synchro      ***
******************************
Clock-domain crossing module for safely transferring a floag event from the aCLK domain to bCLK domain.
Converts the input flag into a toggle signal, synchronizes it into the destination clock domain, and then detects the toggle to generate a one-cycle pulse.
*/

module SYNCflag(
	input aRST,
	input aCLK,
	input aFLAG,
	input bRST,
	input bCLK,
	output bFLAG
);
	reg flag;
	//Convert aFLAG to toggle signal
	//aFLAG signal should be a event signal that only become True when the event occur.
	//If not, the flag signal can be toggle as aCLK toggle when flag==True.
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