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
	${rtlDir}/adder.v \
	${rtlDir}/tree.v \
	${rtlDir}/multiplier.v \
	${rtlDir}/accumulator.v \
	${rtlDir}/pe.v \
	${rtlDir}/sa.v; \
	hierarchy -top sa; proc; opt; \
	show -format dot -prefix sa sa"

dot -Tpng sa.dot > sa.png
eog sa.png &

#inkscape accumulator.svg
