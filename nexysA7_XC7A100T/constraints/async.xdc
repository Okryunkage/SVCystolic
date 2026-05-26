set_clock_groups -asynchronous \
	-group [get_clocks boardCLKpin] \
	-group [get_clocks clk_pll_i]
	#in TCL console, type "set_property PROCESSING_ORDER LATE [get_files constraints.xdc]"
	#if don't, set_clock_groups can applied earlier than clk_pll_i instantiation
	#ignore upper annotation. Type bottom command in TCL console.
	#set_property USED_IN_SYNTHESIS false [get_files async.xdc]
	#set_property USED_IN_IMPLEMENTATION true [get_files async.xdc]
	#set_property PROCESSING_ORDER LATE [get_files async.xdc]
