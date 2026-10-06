#!/usr/bin/env bash
set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
currentDir="$(pwd -P)"
rtlDir="$rootDir/rtl/CNN_BRAM_XPM"
tbDir="$rootDir/testbench"
hDir="$rootDir/header"
buildDir="$rootDir/.build/verilator_convBRAM"

topModule="tb_convBRAM"
binaryName="sim_convBRAM"

#buildJobs="${BUILD_JOBS:-$(nproc)}"
#simThreads="${SIM_THREADS:-$(nproc)}"
buildJobs=8
simThreads=8

echo "rootDir    = $rootDir"
echo "currentDir = $currentDir"
echo "rtlDir     = $rtlDir"
echo "tbDir      = $tbDir"
echo "hDir       = $hDir"
echo "buildDir   = $buildDir"
echo "buildJobs  = $buildJobs"
echo "simThreads = $simThreads"

mkdir -p "$buildDir"

verilator \
	--binary \
	--timing \
	--trace \
	--trace-structs \
	--threads "$simThreads" \
	-j "$buildJobs" \
	-Wall \
	-Wno-fatal \
	--top-module "$topModule" \
	--Mdir "$buildDir" \
	-o "$binaryName" \
	-I"$rtlDir" \
	-I"$currentDir" \
	-I"$hDir" \
	-I"$tbDir" \
	"$rtlDir/convCore.sv" \
	"$rtlDir/convMEM.sv" \
	"$rtlDir/convTOP.sv" \
	"$tbDir/xpm_memory_spram_sim.v" \
	"$tbDir/CNN/tb_convBRAM.sv"

cd "$currentDir"

echo "=== Actual memory file ==="
pwd
realpath tb_conv_w_tile.mem
cat -n tb_conv_w_tile.mem
echo "=== File bytes ==="
od -An -tx1c tb_conv_w_tile.mem
"$buildDir/$binaryName"

if [[ "${SHOW_WAVE:-0}" == "1" && -f out.vcd ]]; then
	gtkwave out.vcd &
fi