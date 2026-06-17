set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/rtlREV"
tbDir="$rootDir/testbench"

echo $rootDir
echo $currentDir
echo $rtlDir
echo $tbDir

iverilog -g2012 -Wall \
	"$rtlDir/0elem/multiplier.v" \
	"$rtlDir/0elem/multiplierTOP.v" \
	"$rtlDir/0elem/adder.v" \
	"$rtlDir/0elem/accumulator.v" \
	"$rtlDir/0elem/tree.v" \
	"$rtlDir/0pe/C_SA.v" \
	"tb_C_SA_pip.v" \
	-o out1
vvp out1
#gtkwave out.vcd &
