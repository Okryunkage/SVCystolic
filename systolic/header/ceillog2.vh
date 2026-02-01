`ifndef ceil_vh
`define  ceil_vh

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

`endif
