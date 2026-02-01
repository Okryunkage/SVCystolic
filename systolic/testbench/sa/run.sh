set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/rtl"
tbDir="$rootDir/testbench"
hDir="$rootDir/header"

echo $rootDir
echo $currentDir
echo $rtlDir
echo $tbDir
echo $hDir

iverilog -g2012 -Wall \
	-I "$rtlDir" \
	-I "$currentDir" \
	-I "$hDir" \
	"tb_proposed_final.v" \
	-o out
vvp out
gtkwave out.vcd &
