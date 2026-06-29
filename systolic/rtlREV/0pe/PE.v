`timescale 1ns/1ps

module PE#(
        parameter integer size=16)(
        clk, en,
        weight, in, psum0, psum1,
        weightO, inO, psumO0, psumO1);
        localparam integer bussize =$clog2(size)+16;
        localparam integer buswire =bussize-1;
        input wire             clk, en;
        input wire[7:0]        weight, in;
        input wire[buswire:0]  psum0, psum1;
        output reg[7:0]        weightO, inO;
        output wire[buswire:0] psumO0, psumO1;
        reg[buswire:0] psumreg0, psumreg1;
        always@(posedge clk)begin
                if(en) weightO <=weight;
                else begin
                        inO <=in;
                        psumreg0 <=psum0;
                        psumreg1 <=psum1;
                end
        end
        wire[15:0] out0,out1;
        mulTOPpip mul(.clk(clk),.multiplier(weightO),.multiplicant(inO),.result0(out0),.result1(out1));
        accumulator#(size) acc(out0,out1,psumreg0,psumreg1,psumO0,psumO1);
endmodule

module PE16(
        clk, en, weight, in,
        weightO, inO, psumO0, psumO1);
        input wire             clk, en;
        input wire [7:0]       weight, in;
        output reg [7:0]       weightO, inO;
        output wire[15:0] psumO0, psumO1;
        always@(posedge clk)begin
                if(en) weightO <=weight;
                else   inO     <=in;
        end
        mulTOPpip mul(.clk(clk),.multiplier(weightO),.multiplicant(inO),.result0(psumO0),.result1(psumO1));
endmodule

module PE17(
        clk, en, weight, in, psum0, psum1,
        weightO, inO, psumO0, psumO1);
        localparam integer size    =2;
        localparam integer bussize =$clog2(size)+16;
        localparam integer buswire =bussize-1;
        input wire             clk, en;
        input wire [7:0]       weight, in;
        input wire [buswire:0] psum0,psum1;
        output wire[7:0]       weightO, inO;
        output wire[buswire:0] psumO0, psumO1;

        PE#(size) uPE(clk,en,weight,in,psum0,psum1,weightO,inO,psumO0,psumO1);
endmodule

module PE18(
        clk, en, weight, in, psum0, psum1,
        weightO, inO, psumO0, psumO1);
        localparam integer size    =4;
        localparam integer bussize =$clog2(size)+16;
        localparam integer buswire =bussize-1;
        input wire             clk, en;
        input wire [7:0]       weight, in;
        input wire [buswire:0] psum0,psum1;
        output wire[7:0]       weightO, inO;
        output wire[buswire:0] psumO0, psumO1;

        PE#(size) uPE(clk,en,weight,in,psum0,psum1,weightO,inO,psumO0,psumO1);
endmodule

module PE19(
        clk, en, weight, in, psum0, psum1,
        weightO, inO, psumO0, psumO1);
        localparam integer size    =8;
        localparam integer bussize =$clog2(size)+16;
        localparam integer buswire =bussize-1;
        input wire             clk, en;
        input wire [7:0]       weight, in;
        input wire [buswire:0] psum0,psum1;
        output wire[7:0]       weightO, inO;
        output wire[buswire:0] psumO0, psumO1;

        PE#(size) uPE(clk,en,weight,in,psum0,psum1,weightO,inO,psumO0,psumO1);
endmodule

module PE20(
        clk, en, weight, in, psum0, psum1,
        weightO, inO, psumO0, psumO1);
        localparam integer size    =16;
        localparam integer bussize =$clog2(size)+16;
        localparam integer buswire =bussize-1;
        input wire             clk, en;
        input wire [7:0]       weight, in;
        input wire [buswire:0] psum0,psum1;
        output wire[7:0]       weightO, inO;
        output wire[buswire:0] psumO0, psumO1;

        PE#(size) uPE(clk,en,weight,in,psum0,psum1,weightO,inO,psumO0,psumO1);
endmodule

module PE21(
        clk, en, weight, in, psum0, psum1,
        weightO, inO, psumO0, psumO1);
        localparam integer size    =32;
        localparam integer bussize =$clog2(size)+16;
        localparam integer buswire =bussize-1;
        input wire             clk, en;
        input wire [7:0]       weight, in;
        input wire [buswire:0] psum0,psum1;
        output wire[7:0]       weightO, inO;
        output wire[buswire:0] psumO0, psumO1;

        PE#(size) uPE(clk,en,weight,in,psum0,psum1,weightO,inO,psumO0,psumO1);
endmodule

module PE22(
        clk, en, weight, in, psum0, psum1,
        weightO, inO, psumO0, psumO1);
        localparam integer size    =64;
        localparam integer bussize =$clog2(size)+16;
        localparam integer buswire =bussize-1;
        input wire             clk, en;
        input wire [7:0]       weight, in;
        input wire [buswire:0] psum0,psum1;
        output wire[7:0]       weightO, inO;
        output wire[buswire:0] psumO0, psumO1;

        PE#(size) uPE(clk,en,weight,in,psum0,psum1,weightO,inO,psumO0,psumO1);
endmodule