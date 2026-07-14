#!/usr/bin/env bash
# Functional sim of flattened unmapped netlist + Yosys sim cells + SST26
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

NET="${1:-synth/zxip_top_unmapped.v}"
if [[ ! -f "$NET" ]]; then
  echo "Missing $NET — run synthesis first:"
  echo "  yosys -l synth/synth_sky130.log -s synth/synth_sky130.ys"
  exit 1
fi

YOSYS_DAT="$(yosys-config --datdir)"
SIMCELLS="$YOSYS_DAT/simcells.v"
SIMLIB="$YOSYS_DAT/simlib.v"

mkdir -p sim
echo "Unmapped netlist: $NET"
echo "Sim cells: $SIMCELLS"

iverilog -g2005 -o sim/zxip_unmapped \
  "$SIMLIB" \
  "$SIMCELLS" \
  "$NET" \
  tb/tb_xip_unmapped.v \
  sst26wf080b.v

vvp sim/zxip_unmapped
