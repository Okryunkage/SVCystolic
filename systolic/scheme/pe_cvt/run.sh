set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/rtl"
tbDir="$rootDir/testbench"

echo $rootDir
echo $currentDir
echo $rtlDir
echo $tbDir

#yosys -p "read_verilog \
#	${rtlDir}/accumulator.v \
#	${rtlDir}/adder.v; \
#	hierarchy -top accumulator; proc; opt; \
#	show -format svg -prefix accumulator accumulator"

yosys -p "read_verilog \
	${rtlDir}/pe_cvt.v \
	${rtlDir}/multiplier.v \
	${rtlDir}/tree.v \
	${rtlDir}/adder.v; \
	hierarchy -top pe_cvt; \
	proc; \
	opt; \
	show -format dot -prefix pe_cvt pe_cvt"

dot -Tpng pe_cvt.dot > pe_cvt.png
eog pe_cvt.png &
