set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/rtl/0MLP_BRAM"
tbDir="$rootDir/testbench"
hDir="$rootDir/../NNmodel/MNISTmlp/hidden64"

echo "$rootDir"
echo "$currentDir"
echo "$rtlDir"
echo "$tbDir"
echo "$hDir"

label="${1:-0}"
#label=0 if there's no factor

iverilog -g2012 -Wall \
	-I "$rtlDir" \
	-I "$currentDir" \
	-I "$hDir" \
	"tbMNIST.v" \
	-o out

vvp out +EXPECTED_LABEL="$label"
#gtkwave out.vcd &