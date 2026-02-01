set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/rtl"
tbDir="$rootDir/testbench"

iverilog -g2012 -Wall \
	-I "$rtlDir" \
	-I "$currentDir" \
	"tb_bka.v" \
	-o out
vvp out
gtkwave out.vcd &
