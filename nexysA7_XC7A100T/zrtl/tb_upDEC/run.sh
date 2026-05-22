set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/zrtl/mlpDRAM"

echo "$rootDir"
echo "$currentDir"
echo "$rtlDir"


iverilog -g2012 -Wall \
	-I "$rtlDir" \
	-I "$currentDir" \
	"tbUP_DEC.v" \
	-o out

vvp out
#gtkwave out.vcd &