`timescale 1ns/1ps

module bka #(
	parameter integer size =32)(
	input [(size-1):0] a,
	input [(size-1):0] b,
	input cin,
	output [(size-1):0] sum,
	output cout);
	
	function integer ceillog2;
		input integer value;
		integer v;
		begin
			if(value<=1) ceillog2=0;
			else begin
				v=value-1;
				ceillog2=0;
				while(v>0)begin
					ceillog2=ceillog2+1;
					v =v>>1;
				end
			end
		end
	endfunction
	
	localparam integer log = ceillog2(size);
	localparam integer sizel = (1<<log); //size_local
	
	wire [(sizel-1):0] pad_a, pad_b;
	generate
		if(sizel==size)begin
			assign pad_a=a;
			assign pad_b=b;
		end
		else begin
			assign pad_a={{(sizel-size){a[size-1]}},a};
			assign pad_b={{(sizel-size){b[size-1]}},b};
		end
	endgenerate

	wire [(sizel-1):0] p0,g0;
	genvar i;
	generate
		for(i=0;i<size;i=i+1)begin:pg
			halfadder gen(pad_a[i],pad_b[i],p0[i],g0[i]);
		end
	endgenerate

	generate
		//if(sizel==1)begin
		//assign sum[0]=p0[0]^cin;
		//assign cout=g0[0]|(p0[0]&cin);
		
		//UP-sweep
		genvar j,k;
		for(j=0;j<log;j=j+1)begin:up
			wire [(sizel-1):0] gin,pin,g,p;
			if(j==0)begin
				assign gin=g0;
				assign pin=p0;
			end
			else begin
				assign gin=up[j-1].g;
				assign pin=up[j-1].p;
			end

			localparam integer distance=(1<<j);
			localparam integer step=(1<<(j+1));

			for(k=0;k<sizel;k=k+1)begin:node
				if(((k+1)%(step))==0)begin:block
					blackCell bc(
						.gc(gin[k]),
						.pc(pin[k]),
						.gp(gin[k-distance]),
						.pp(pin[k-distance]),
						.gn(g[k]),
						.pn(p[k]));
				end
				else begin:propagate
					assign g[k]=gin[k];
					assign p[k]=pin[k];
				end
			end
		end
		//Down-sweep
		genvar l,m;
		//if(log>1)begin:gen_down
		for(l=0;l<(log-1);l=l+1)begin:down
			wire [(sizel-1):0] gin,pin;
			wire [(sizel-1):0] g,p;
			if(l==0)begin
				assign gin=up[log-1].g;
				assign pin=up[log-1].p;
			end
			else begin
				assign gin=down[l-1].g;
				assign pin=down[l-1].p;
			end

			localparam integer exponent=(log-2-l);
			localparam integer distance=(1<<exponent);
			localparam integer step=(1<<(exponent+1));

			for(m=0;m<sizel;m=m+1)begin:node
				if((((m+1)%step)==distance)&&((m+1)>=(3*distance)))begin:block
					blackCell bc(
						.gc(gin[m]),
						.pc(pin[m]),
						.gp(gin[m-distance]),
						.pp(pin[m-distance]),
						.gn(g[m]),
						.pn(p[m]));
				end
				else begin:propagate
					assign g[m]=gin[m];
					assign p[m]=pin[m];
				end
			end
		end
		
		wire [(sizel-1):0] glast,plast;
		//if(log==1)begin:last_up
		//	assign glast=up[0].g;
		//	assign plast=up[0].p;
		//end
		//else begin:last_down
		assign glast=down[log-2].g;
		assign plast=down[log-2].p;
		//end

		wire [size:0] c;
		assign c[0] =cin;

		genvar n;
		for(n=0;n<size;n=n+1)begin:out
			grayCell gc(
				.gc(glast[n]),
				.pc(plast[n]),
				.gp(cin),
				.gn(c[n+1]));
			assign sum[n] = p0[n]^c[n];
		end
		assign cout = c[size];
	//end_when using if(n==1) above
	endgenerate
endmodule

module bkaS #(
	parameter integer size=32)(
	input [(size-1):0] a,
	input [(size-1):0] b,
	output [(size-1):0] sum);
	bka #(size) bkaI(a,b,(1'b0),sum,);
endmodule
