#!/usr/bin/env bash
# Synth + SS STA @ 12 ns for cache geometries.
# Usage: ./scripts/run_geom_ss_12ns.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IMG="${OPENSTA_IMAGE:-openroad/opensta:latest}"
PLATFORM="${OPENSTA_PLATFORM:-linux/amd64}"
SDC="$ROOT/sta/zxip_top_12ns.sdc"
PERIOD_PS=12000

mkdir -p synth/out sta/reports/geom_12ns

run_one () {
  local LINES="$1"
  local BYTES="$2"
  local TAG="L${LINES}_B${BYTES}"
  local NET="$ROOT/synth/out/zxip_top_${TAG}.v"
  local LOG="$ROOT/synth/out/synth_${TAG}.log"
  local RPT="$ROOT/sta/reports/geom_12ns/${TAG}"
  local STA_LOG="$ROOT/sta/reports/geom_12ns/${TAG}_opensta.log"

  echo "============================================================"
  echo " SYNTH  ${LINES} lines x ${BYTES} B/line  ABC -D ${PERIOD_PS} (12 ns)"
  echo "============================================================"

  yosys -D "XIP_CACHE_LINES=${LINES}" -D "XIP_LINE_BYTES=${BYTES}" \
    -l "$LOG" -p "
read_verilog -I rtl \
  rtl/zxip_apb_regs.v \
  rtl/zxip_phy.v \
  rtl/zxip_fill_fsm.v \
  rtl/zxip_cache.v \
  rtl/zxip_ahb_slave.v \
  rtl/zxip_top.v
hierarchy -check -top zxip_top
flatten
opt_clean
proc
opt
fsm
opt
memory
opt -purge
techmap
opt
clean
read_liberty -lib sky130/hd_120e_ss.lib
dfflibmap -liberty sky130/hd_120e_ss.lib
opt
abc -liberty sky130/hd_120e_ss.lib \
    -constr synth/abc_sky130.constr \
    -D ${PERIOD_PS} \
    -script synth/abc_map.script
clean
opt
stat -liberty sky130/hd_120e_ss.lib
write_verilog -noattr -noexpr ${NET}
write_json synth/out/zxip_top_${TAG}.json
"

  echo "============================================================"
  echo " STA SS  ${TAG}  period=12 ns"
  echo "============================================================"
  mkdir -p "$RPT"

  docker run --rm --platform "$PLATFORM" \
    --entrypoint /OpenSTA/build/sta \
    -e CORNER=ss \
    -e LIB_PATH=/work/sky130/hd_120e_ss.lib \
    -e NET="/work/synth/out/$(basename "$NET")" \
    -e SDC=/work/sta/zxip_top_12ns.sdc \
    -e RPT_DIR="/work/sta/reports/geom_12ns/${TAG}" \
    -v "$ROOT:/work" \
    -w /work \
    "$IMG" \
    -no_splash -exit /work/sta/run_opensta_corner.tcl \
    2>&1 | tee "$STA_LOG"

  # Extract summary
  {
    echo "===== ${TAG} (${LINES}x${BYTES} B) @ 12 ns SS ====="
    echo "--- Yosys area/cells ---"
    rg -n "Chip area|cells$|  [0-9]+ .*sky130|Chip area for" "$LOG" | tail -60
    echo
    echo "--- STA WNS/TNS/worst ---"
    cat "$RPT/wns.rpt" 2>/dev/null || true
    cat "$RPT/tns.rpt" 2>/dev/null || true
    cat "$RPT/worst_slack_max.rpt" 2>/dev/null || true
    cat "$RPT/worst_slack_min.rpt" 2>/dev/null || true
    echo
  } | tee -a "$ROOT/sta/reports/geom_12ns/summary.txt"
}

: > "$ROOT/sta/reports/geom_12ns/summary.txt"

run_one 8 8
run_one 8 16

echo
echo "======== FINAL SUMMARY ========"
cat "$ROOT/sta/reports/geom_12ns/summary.txt"
