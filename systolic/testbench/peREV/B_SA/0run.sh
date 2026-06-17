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
	"$rtlDir/0elem/bka.v" \
	"$rtlDir/0pe/B_SA.v" \
	"tb_B_SA.v" \
	-o out
vvp out
#gtkwave out.vcd &
