set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/rtl"
tbDir="$rootDir/testbench"

echo $rootDir
echo $currentDir
echo $rtlDir
echo $tbDir

iverilog -g2012 -Wall \
	-I "$rtlDir" \
	-I "$currentDir" \
	"tb_pe.v" \
	-o out
vvp out
gtkwave out.vcd &
