`timescale 1ns/1ps

module proposed(
	clk, en, weight, in, result);
	localparam integer size =32;
	localparam integer outW =21;
	input wire                   clk, en;
	input wire [(8*size-1):0]    weight, in;
	output wire[(size*outW-1):0] result;

	function integer psumWidth;
		input integer rowNum;begin
			if     (rowNum<=1)  psumWidth =16;
			else if(rowNum<=2)  psumWidth =17;
			else if(rowNum<=4)  psumWidth =18;
			else if(rowNum<=8)  psumWidth =19;
			else if(rowNum<=16) psumWidth =20;
			else                psumWidth =21;
		end
	endfunction

	genvar i, j;
	generate
		for(i=0;i<size;i=i+1)begin:c
			for(j=0;j<size;j=j+1)begin:r
				localparam integer W =psumWidth(j+1);
				wire signed[7:0]     weightP;
				wire signed[7:0]     inP;
				wire signed[(W-1):0] psum0P;
				wire signed[(W-1):0] psum1P;
			end
		end
	endgenerate
	generate
		for(i=0;i<size;i=i+1)begin:column
			for(j=0;j<size;j=j+1)begin:row
				localparam integer W  =psumWidth(j+1);
				localparam integer PW =(j==0)?W:psumWidth(j);
				wire signed[7:0]     weightIn;
				wire signed[7:0]     inIn;
				wire signed[(W-1):0] psum0In;
				wire signed[(W-1):0] psum1In;
				
				if(j==0)begin:firstRow
					assign weightIn =weight[(i*8)+:8];
					assign inIn     =in[(i*8)+:8];
					PE16 PE(.clk(clk),.en(en),
						.weight(weight),.in(inIn),
						.weightO(c[i].r[j].weightP),.inO(c[i].r[j].inP),
						.psumO0(c[i].r[j].psum0P),.psumO1(c[i].r[j].psum1P));
				end

				else begin:otherRows
					assign weightIn =c[i].r[j-1].weightP;
					assign inIn     =c[(i+size/2+1)%size].r[j-1].inP;
					if(W==PW)begin:noExtend
						assign psum0In =c[i].r[j-1].psum0P;
						assign psum1In =c[i].r[j-1].psum1P;
					end
					else begin:signExtend
						assign psum0In ={{(W-PW){c[i].r[j-1].psum0P[PW-1]}},c[i].r[j-1].psum0P};
						assign psum1In ={{(W-PW){c[i].r[j-1].psum1P[PW-1]}},c[i].r[j-1].psum1P};
					end
					if(W==17)begin:genPE17
						PE17 PE(.clk(clk),.en(en),
							.weight(weightIn),.in(inIn),
							.psum0(psum0In),.psum1(psum1In),
							.weightO(c[i].r[j].weightP),.inO(c[i].r[j].inP),
							.psumO0(c[i].r[j].psum0P),.psumO1(c[i].r[j].psum1P));
					end
					else if(W==18)begin:genPE18
						PE18 PE(.clk(clk),.en(en),
							.weight(weightIn),.in(inIn),
							.psum0(psum0In),.psum1(psum1In),
							.weightO(c[i].r[j].weightP),.inO(c[i].r[j].inP),
							.psumO0(c[i].r[j].psum0P),.psumO1(c[i].r[j].psum1P));
					end
					else if(W==19)begin:genPE19
						PE19 PE(.clk(clk),.en(en),
							.weight(weightIn),.in(inIn),
							.psum0(psum0In),.psum1(psum1In),
							.weightO(c[i].r[j].weightP),.inO(c[i].r[j].inP),
							.psumO0(c[i].r[j].psum0P),.psumO1(c[i].r[j].psum1P));
					end
					else if(W==20)begin:genPE20
						PE20 PE(.clk(clk),.en(en),
							.weight(weightIn),.in(inIn),
							.psum0(psum0In),.psum1(psum1In),
							.weightO(c[i].r[j].weightP),.inO(c[i].r[j].inP),
							.psumO0(c[i].r[j].psum0P),.psumO1(c[i].r[j].psum1P));
					end
					else if(W==21)begin:genPE21
						PE21 PE(.clk(clk),.en(en),
							.weight(weightIn),.in(inIn),
							.psum0(psum0In),.psum1(psum1In),
							.weightO(c[i].r[j].weightP),.inO(c[i].r[j].inP),
							.psumO0(c[i].r[j].psum0P),.psumO1(c[i].r[j].psum1P));
					end
				end
			end
			assign result[(i*outW)+:outW] =$signed(c[i].r[size-1].psum0P)+$signed(c[i].r[size-1].psum1P);
		end
	endgenerate
endmodule