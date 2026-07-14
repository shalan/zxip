#!/usr/bin/env bash
# 32-bit AHB host smoke (HOST_DW=32, HOST_AW=32) vs SST26
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
mkdir -p sim

LINES="${LINES:-16}"
BYTES="${BYTES:-16}"
OUT="sim/zxip_ahb32_L${LINES}_B${BYTES}"

echo "Building AHB32 TB: ${LINES} lines x ${BYTES} B/line"
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
  tb/tb_zxip_ahb32.v \
  sst26wf080b.v
vvp "$OUT" "$@"
