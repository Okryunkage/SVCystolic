set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/zrtl/rtl_mlpDRAM"

echo "$rootDir"
echo "$currentDir"
echo "$rtlDir"


iverilog -g2012 -Wall \
	-I "$rtlDir" \
	-I "$currentDir" \
	"tb_pacDEC.v" \
	-o out

vvp out
#gtkwave out.vcd &