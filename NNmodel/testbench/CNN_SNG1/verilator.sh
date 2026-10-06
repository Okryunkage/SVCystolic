#!/usr/bin/env bash
set -euo pipefail

rootDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
currentDir="$(pwd -P)"
rtlDir="$rootDir/rtl/CNN_BRAM_SNG"
tbDir="$rootDir/testbench"
hDir="$rootDir/header"
buildDir="$rootDir/.build/verilator_convBRAM"

topModule="tb_conv"
binaryName="sim_conv"

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
	"$rtlDir/0functions/requantize.sv" \
	"$rtlDir/0networks/convCore.sv" \
	"$rtlDir/0networks/convMEM.sv" \
	"$rtlDir/0networks/convTOP.sv" \
	"$currentDir/xpm_memory_spram_sim.sv" \
	"$currentDir/tb_conv.sv"

cd "$currentDir"
"$buildDir/$binaryName"

if [[ "${SHOW_WAVE:-0}" == "1" && -f out.vcd ]]; then
	gtkwave out.vcd &
fi