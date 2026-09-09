set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/rtl/0SA_BRAM_rev"
#tbDir="$rootDir/testbench"
#headerDir="$rootDir/header"

iverilog -g2012 -Wall \
	-I "$rtlDir" \
	-I "$currentDir" \
	-I "$rtlDir" \
	"$rtlDir/multiplier.v" \
	"$rtlDir/tree.v" \
	"$rtlDir/adder.v" \
	"$rtlDir/pe_cvt.v" \
	"$rtlDir/SA_cvt.v" \
	"$rtlDir/SA_IOr.v" \
	"$rtlDir/SA_btr.v" \
	"$rtlDir/xpm_memory_spram_sim.v" \
	"$rtlDir/bram_spram.v" \
	"$rtlDir/linear10Engine.v" \
	"$rtlDir/uartTOP.v" \
	"$rtlDir/predSender.v" \
	"$rtlDir/batchLoader.v" \
	"$rtlDir/fpgaTOP.v" \
	"tb_fpgaTOP.v" \
	-o out
vvp out
#gtkwave out.vcd &