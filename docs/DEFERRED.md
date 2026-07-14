# Deferred work (post–Phase 6 core)

These items are **intentionally postponed**. Specs for the main path remain in `specs.md` / `RTL_PLAN.md`.

## Deferred from Phase 4 — S28HS SDR co-sim

**Goal:** Prove the same RTL against Infineon `s28hs256m4.sv` without continuous mode.

| Item | Detail |
|------|--------|
| Profile | `XIP_MODE=1`, `MODE_PHASE_EN=0`, `CONT_EN=0`, `DTR_EN=0` |
| `DUMMY` | SPI Fast Read **8**; QSPI `0xEB` **20** (default CFR2V=`0x08`) |
| Simulator | SystemVerilog-capable (VCS / Xcelium / Questa); not plain iverilog |
| TB | Expand `tb/tb_xip_s28hs.sv` with AHB scoreboard + mem preload |
| Pin adapter | SI/SO/DQ2/DQ3, CSNeg, RESETNeg, optional DS |
| Do not enable | Device QPI (`CFR5`) |

**Why later:** Needs SV tool chain; SST26 already covers 1-1-1, 1-4-4, continuous, paging.

---

## Deferred from Phase 5 — DTR (`0xED`, 1S-4D-4D)

**Goal:** Dual-edge address/data on 4 IOs; command remains 1-line SDR.

| Item | Detail |
|------|--------|
| Opcode | Default `0xED` (`QSPI_CMD` high byte) |
| PHY | Launch/capture on **both** SCK edges during 4D phases |
| Optional | `DTR_PHY.SAMP_DLY`, sample-edge invert; optional DS strobe |
| Primary VIP | S28HS; keep `DTR_EN=0` on SST26 unless separately proven |
| Fill FSM | Today: `dtr_en && xip_mode` → sticky `fill_err` (stub) |

**Why later:** Timing-sensitive; little ROI until SDR path + prefetch are solid on the target board.

### Suggested DTR implementation order (when resumed)

1. Dual-edge SCK phase gen in `xip_phy` (even `CLKDIV`).  
2. QSPI address 3 SCK (4D) + data 16 SCK for 16 B.  
3. CSR `DTR_EN` path in fill FSM (replace error stub).  
4. TB vs S28HS @ slow SCK, then raise rate.  
5. Optional DS-based capture.

---

## Related future (not Phase 5)

| Item | Notes |
|------|--------|
| Parameterized **16/32-bit AHB data** | See README — not free; needs lane steering + TB |
| True block RAM cache | Tech-map / FPGA BRAM inference |
| Command-less continuous on non-SST parts | Vendor-specific mode bytes already CSR-driven |
