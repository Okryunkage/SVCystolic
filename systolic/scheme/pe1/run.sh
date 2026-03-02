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
	${rtlDir}/pe.v \
	${rtlDir}/accumulator.v \
	${rtlDir}/multiplier.v \
	${rtlDir}/tree.v \
	${rtlDir}/adder.v; \
	hierarchy -top pe1; \
	proc; \
	opt; \
	show -format dot -prefix pe1 pe1"

dot -Tpng pe1.dot > pe1.png
eog pe1.png &
