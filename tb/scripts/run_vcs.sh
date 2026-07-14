#!/usr/bin/env bash
# Co-sim RTL (Verilog-2005) + s28hs256m4.sv — requires VCS + SV
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
mkdir -p sim
python3 tb/scripts/gen_mem.py
# Copy/link mem next to sim if model opens CWD name
cp -f tb/mem/s28hs256m4.mem sim/s28hs256m4.mem 2>/dev/null || true
cp -f tb/mem/s28hs256m4.mem ./s28hs256m4.mem 2>/dev/null || true

vcs -full64 -sverilog -timescale=1ps/1ps \
  +incdir+rtl \
  rtl/zxip_top.v \
  tb/tb_xip_s28hs.sv \
  s28hs256m4.sv \
  -o sim/zxip_sim \
  -l sim/compile.log

./sim/zxip_sim -l sim/run.log
