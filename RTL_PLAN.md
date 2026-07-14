# XiP QSPI Controller — RTL Implementation Plan (Verilog-2005)

This plan implements `specs.md` with **IEEE Verilog-2005** RTL and verifies against **pluggable** flash models (examples: **`sst26wf080b.v`**, **`s28hs256m4.sv`**).

## 0. Goals and constraints

| Item | Choice |
|------|--------|
| RTL language | **Verilog-2005 only** (`*.v`) — no `logic`, interfaces, always_ff, SV assertions in RTL |
| Testbench | Verilog or SV; adapter + **profile** per VIP |
| Flash VIPs | **Examples only** — SST26 (1 MB, continuous), S28HS (32 MB model, DTR); add more without changing RTL |
| Protocols | **1-1-1 SDR**, **1-4-4 SDR**, optional **1S-4D-4D** |
| Continuous | Optional (`CONT_EN` + mode phase) — on for SST26 profile, off for S28HS |
| Cache | 16 lines × 16 B, direct-mapped, phys-tagged, RO |

## 1. Repository layout

```text
xip/
  specs.md
  RTL_PLAN.md
  sst26wf080b.v               # example VIP (Microchip SST26)
  s28hs256m4.sv               # example VIP (Infineon SEMPER)
  rtl/                        # Verilog-2005 controller (vendor-agnostic)
  tb/
    tb_xip_sst26.v            # co-sim + SST26 adapter + profile
    tb_xip_s28hs.sv           # co-sim + S28HS adapter + profile
    flash_if/                 # optional shared adapters
    mem/                      # generated preloads
    scripts/
      gen_mem.py
      run_sst26_iverilog.sh   # RTL + SST26 (often pure Verilog)
      run_s28hs_vcs.sh        # RTL + S28HS (needs SV)
  sim/
```

## 2. Coding rules (Verilog-2005)

1. `timescale 1ns/1ps` in RTL (TB overrides / uses 1ps for flash).  
2. ANSI-style ports OK (Verilog-2001/2005).  
3. Prefer `reg`/`wire`; no `logic`.  
4. No `always_comb` / `always_ff` — use `always @*` and `always @(posedge clk or negedge rst_n)`.  
5. No interfaces, packages, or classes in RTL.  
6. Parameters for cache geometry and address widths.  
7. Synchronous active-low reset on AHB/APB domain.  
8. SPI pad outputs registered; avoid glitches on `CS#`/`SCK`.

## 3. Module responsibilities

### 3.1 `xip_top`

- Ports: AHB-Lite 16-bit slave, APB 16-bit slave, page sideband (`fixed_page`, `page_sel`, `page_is_flash`), SPI pads.  
- Builds `phys[19:0]` for fixed vs paged decode (or accepts external `phys` + `xip_sel`).  
- Arbitrates pin mux: fill engine vs bit-bang.  
- Instantiates: AHB slave, cache, fill+PHY, APB regs, bitbang.

### 3.2 `xip_ahb_slave`

- Accept read `HTRANS` NONSEQ/SEQ when selected.  
- `HWRITE=1` → `HRESP=ERROR`, `HREADY` handshake complete.  
- Present `{hit, halfword, phys}` to cache; stretch `HREADY` on miss until fill returns data.  
- Byte/halfword `HSIZE` only.

### 3.3 `xip_cache`

- Arrays: `valid[15]`, `tag[15][11:0]`, `data[15][127:0]`.  
- Lookup: index=`phys[7:4]`, tag=`phys[19:8]`.  
- On hit: return halfword `data[index][8*offset +: 16]` (little-endian halfwords).  
- On miss: pulse `fill_req`, wait `fill_done` + `fill_line[127:0]`, install, complete.  
- `inv_all` from CSR.

### 3.4 `xip_fill_fsm` + `xip_phy`

FSM: `IDLE → CMD → ADDR → LAT → DATA → DONE → IDLE`.

| Mode | CMD | ADDR | LAT | DATA (16 B) |
|------|-----|------|-----|-------------|
| 1-1-1 `0x0B` | 8×1S | 24×1S | `DUMMY` | 128×1S on SO |
| 1-1-1 `0x03` | 8×1S | 24×1S | 0 | 128×1S |
| 1-4-4 `0xEB` | 8×1S | 6×4S | `DUMMY` | 32×4S |
| 1-4-4 DTR `0xED` | 8×1S | 3×4D | `DUMMY` | 16×4D |

PHY details:

- Generate `SCK` from `HCLK` / `CLKDIV` (even divisors preferred for DTR).  
- Mode 0: sample MISO/quad on rising (or as required); launch MOSI on falling for standard SPI.  
- DTR: launch/capture on both edges during ADDR/DATA; optional ignore `DS` v1.  
- After ADDR, force `IO` OE=0 for latency+data.  
- Critical-word-first: optional phase-2; v1 may return after full line.

### 3.5 `xip_apb_regs` + `xip_bitbang`

- Implement CSR map in `specs.md` §8.4.  
- Bit-bang drives pads only when `BB_EN && !XIP_EN`.  
- Reserved CONT fields: hardwire 0.

## 4. Implementation phases

### Phase 0 — Scaffold (0.5 d)

- [x] Create tree, `xip_pkg_params.vh`, modules with ports.  
- [x] TB POR smoke (SST26 + S28HS).  
- [x] Mem preload pattern in TB.

### Phase 1 — APB + bit-bang smoke (1 d)

- [x] CSR R/W (`xip_apb_regs.v`).  
- [x] Bit-bang pad fields + mutex (`bb_active = BB_EN & ~XIP_EN`).  
- [ ] Dedicated BB pin-toggle smoke test (optional).

### Phase 2 — PHY + 1-1-1 fill only (2–3 d)

- [x] `xip_phy` + `xip_fill_fsm` for `0x0B`/`0x03`.  
- [x] **Gate:** SST26 preload match (`./tb/scripts/run_sst26_iverilog.sh`).

### Phase 3 — Cache + AHB (2 d)

- [x] Direct-map cache + AHB slave.  
- [x] Miss → fill → hit path.  
- [ ] Write → ERROR test (stub in TB later).  
- [x] Fixed + paged window decode.

### Phase 4 — 1-4-4 SDR `0xEB` (2 d)

- [x] Quad address + quad data.  
- [x] Mode-byte phase + `CONT_EN` (SST26 profile).  
- [x] Continuous omit-cmd fills when `CONT_ACTIVE`.  
- [x] **Gate:** SST26 1-1-1 + 1-4-4 + continuous.  
- [ ] ~~S28HS full-command profile~~ → **deferred** ([`docs/DEFERRED.md`](docs/DEFERRED.md))

### Phase 5 — DTR `0xED` (2–3 d)

- [ ] ~~Dual-edge / S28HS DTR~~ → **deferred** ([`docs/DEFERRED.md`](docs/DEFERRED.md))  
- Stub today: `DTR_EN` + QSPI → `fill_err` until implemented.

### Phase 6 — Prefetch & polish

- [x] Paged window (page_sel) — already in RTL/TB.  
- [x] Next-line prefetch (`PREFETCH_EN` CTRL[11], window-clipped).  
- [x] AHB write → ERROR test.  
- [x] SST26 full suite including Phase 6.  
- [ ] Critical-word-first (optional; not required for v1).  
- [x] Docs: README + DEFERRED.
## 5. Verification plan (multi-VIP)

### 5.1 Compile notes

```bash
# SST26 — often iverilog-friendly (Verilog VIP)
iverilog -g2005 -I rtl -o sim/xip_sst26 \
  rtl/*.v tb/tb_xip_sst26.v sst26wf080b.v

# S28HS — needs SystemVerilog simulator
vcs -full64 -sverilog -timescale=1ps/1ps +incdir+rtl \
  rtl/*.v tb/tb_xip_s28hs.sv s28hs256m4.sv -o sim/xip_s28hs
```

### 5.2 Profiles (apply in TB before XiP)

| Profile | CONT_EN | MODE_PHASE_EN | DTR | Notes |
|---------|---------|---------------|-----|--------|
| `sst26` | 1 | 1 | 0 | IOC must allow 0xEB; mode stay `0xAx` |
| `s28hs` | 0 | 0 | 0/1 | DUMMY 8 / 20; no QPI |

### 5.3 Test list

| ID | Test | VIP |
|----|------|-----|
| T01 | 1-1-1 boot read | both |
| T02 | Cache hit | both |
| T03 | Tag/index conflict | both |
| T04 | `0x03` path | both |
| T05 | `0xEB` full command | both |
| T06 | `0xEB` continuous (omit cmd) | **sst26** |
| T07 | `0xED` DTR | **s28hs** |
| T08 | AHB write ERROR | both |
| T09 | page_sel | both |
| T10 | BB mutex | both |

### 5.4 Scoreboard

- Expected array from same preload as VIP.  
- Compare `HRDATA` to `expected[phys]` on each AHB read.

## 6. Suggested parameters (`xip_pkg_params.vh`)

```verilog
`ifndef XIP_PKG_PARAMS_VH
`define XIP_PKG_PARAMS_VH
localparam XIP_CACHE_LINES   = 16;
localparam XIP_LINE_BYTES    = 16;
localparam XIP_PHYS_W        = 20;
localparam XIP_SPI_ADDR_W    = 24;
localparam XIP_AHB_AW        = 16;
localparam XIP_AHB_DW        = 16;
// opcodes
localparam [7:0] XIP_CMD_READ      = 8'h03;
localparam [7:0] XIP_CMD_FAST_READ = 8'h0B;
localparam [7:0] XIP_CMD_QIO_SDR   = 8'hEB;
localparam [7:0] XIP_CMD_QIO_DTR   = 8'hED;
`endif
```

## 7. Risk register

| Risk | Mitigation |
|------|------------|
| Vendor protocol differences | **Profiles** (CONT/MODE/DUMMY/DTR) — never hardcode one part |
| SST26 needs IOC for 0xEB | Bit-bang or default config in TB before QSPI |
| S28HS latency / 1 ps | Profile DUMMY; SV timescale |
| DTR fragile | Primary on S28HS only; slow SCK first |
| Multiple VIP modules name clash | One VIP per sim executable |

## 8. Exit criteria (v1 done)

1. T01–T05, T08–T10 pass on **both** example VIPs.  
2. T06 on SST26; T07 on S28HS.  
3. RTL `iverilog -g2005` clean.  
4. Docs list how to add a third VIP (adapter + profile only).

## 9. Immediate next steps

**v1 core (SST26) is complete through Phase 6** (minus optional CWF).

When resuming:
1. S28HS SDR co-sim — `docs/DEFERRED.md`  
2. DTR `0xED` — `docs/DEFERRED.md`  
3. Optional CWF / 16–32-bit AHB data param (see README)
