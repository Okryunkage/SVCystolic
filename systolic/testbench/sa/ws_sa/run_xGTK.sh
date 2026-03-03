set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/rtl"
tbDir="$rootDir/testbench"
headerDir="$rootDir/header"

echo $rootDir
echo $currentDir
echo $rtlDir
echo $tbDir
echo $headerDir

iverilog -g2012 -Wall \
	-I "$rtlDir" \
	-I "$currentDir" \
	-I "$headerDir" \
	"tb_sa.v" \
	-o out
vvp out
#gtkwave out.vcd &
