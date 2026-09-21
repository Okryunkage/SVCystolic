set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
currentDir="$(pwd)"
rtlDir="$rootDir/RTL/CNN_BRAM_XPM"
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
	-I "$tbDir" \
	"$rtlDir/convCore_pipe.sv" \
	"$rtlDir/convMEM.sv" \
	"$rtlDir/convTOP.sv" \
	"$rtlDir/xpm_memory_spram_sim.v" \
	"tb_convBRAM.sv" \
	-o out
vvp out
#gtkwave out.vcd &
