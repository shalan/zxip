#!/usr/bin/env bash
# Multi-corner STA: TT / SS / FF via OpenSTA Docker
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NET="${NET:-$ROOT/synth/zxip_top_sky130.v}"
SDC="$ROOT/sta/zxip_top.sdc"
IMG="${OPENSTA_IMAGE:-openroad/opensta:latest}"
PLATFORM="${OPENSTA_PLATFORM:-linux/amd64}"

if [[ ! -f "$NET" ]]; then
  echo "Missing mapped netlist: $NET"
  echo "Run: yosys -l synth/synth_sky130.log -s synth/synth_sky130.ys"
  exit 1
fi

mkdir -p "$ROOT/sta/reports"
SUMMARY="$ROOT/sta/reports/summary_tt_ss_ff.txt"
: > "$SUMMARY"

echo "Pulling $IMG ($PLATFORM)..."
docker pull --platform "$PLATFORM" "$IMG" >/dev/null

run_corner () {
  local corner="$1"
  local lib="$2"
  local outlog="$ROOT/sta/reports/${corner}_opensta.log"
  echo "==== STA corner=$corner lib=$(basename "$lib") ===="
  docker run --rm --platform "$PLATFORM" \
    --entrypoint /OpenSTA/build/sta \
    -e CORNER="$corner" \
    -e LIB_PATH="/work/sky130/$(basename "$lib")" \
    -e NET="/work/synth/$(basename "$NET")" \
    -e SDC="/work/sta/zxip_top.sdc" \
    -e RPT_DIR="/work/sta/reports/$corner" \
    -v "$ROOT:/work" \
    -w /work \
    "$IMG" \
    -no_splash -exit /work/sta/run_opensta_corner.tcl \
    2>&1 | tee "$outlog" | rg -n "wns |tns |worst slack|corner:|VIOLATED|results|Reports" || true

  {
    echo "===== $corner ====="
    cat "$ROOT/sta/reports/$corner/wns.rpt" 2>/dev/null || true
    cat "$ROOT/sta/reports/$corner/tns.rpt" 2>/dev/null || true
    cat "$ROOT/sta/reports/$corner/worst_slack_max.rpt" 2>/dev/null || true
    cat "$ROOT/sta/reports/$corner/worst_slack_min.rpt" 2>/dev/null || true
    echo
  } >> "$SUMMARY"
}

run_corner tt "$ROOT/sky130/hd_120e_tt.lib"
run_corner ss "$ROOT/sky130/hd_120e_ss.lib"
run_corner ff "$ROOT/sky130/hd_120e_ff.lib"

echo
echo "======== Multi-corner summary ========"
cat "$SUMMARY"
echo "Full reports: sta/reports/{tt,ss,ff}/"
