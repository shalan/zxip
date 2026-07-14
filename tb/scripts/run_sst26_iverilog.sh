#!/usr/bin/env bash
# RTL co-sim vs SST26. Optional cache geometry:
#   LINES=8 BYTES=8  ./tb/scripts/run_sst26_iverilog.sh
#   LINES=8 BYTES=16 ./tb/scripts/run_sst26_iverilog.sh
# Defaults: 16 lines x 16 bytes (256 B)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
mkdir -p sim

LINES="${LINES:-16}"
BYTES="${BYTES:-16}"
OUT="sim/zxip_sst26_L${LINES}_B${BYTES}"

echo "Building SST26 TB: ${LINES} lines x ${BYTES} B/line"
iverilog -g2005 -I rtl \
  -DXIP_CACHE_LINES="${LINES}" \
  -DXIP_LINE_BYTES="${BYTES}" \
  -o "$OUT" \
  rtl/zxip_apb_regs.v \
  rtl/zxip_phy.v \
  rtl/zxip_fill_fsm.v \
  rtl/zxip_cache.v \
  rtl/zxip_ahb_slave.v \
  rtl/zxip_top.v \
  tb/tb_xip_sst26.v \
  sst26wf080b.v
vvp "$OUT" "$@"
