# XiP QSPI Flash Controller — Specification

## 1. Overview

This document specifies a small **eXecute-in-Place (XiP)** QSPI flash controller for a **16-bit data/address** SoC.

### 1.1 Goals

- Map SPI NOR flash into the CPU address space for instruction (and RO data) fetch.
- Provide a **read-only line cache** to hide flash latency on the AHB path.
- Support **exactly two** hardware XiP I/O-width protocols (C–A–D), software-selectable:
  - **1-1-1 SDR** — SPI XiP; **reset default**; safe boot without Quad Enable.
  - **1-4-4** — QSPI XiP Quad I/O; **SDR** (`0xEB`) or **DTR** (`0xED`), SW-selectable.
- Support **DTR (Double Transfer Rate)** on the **1-4-4** path only (1S-4D-4D).
- Support a larger than 64 KB flash image via **physical addressing (20-bit)** and **paged windows**.
- Provide a **simple APB CSR** interface for mode/timing control, and **bit-bang SPI only for programming** the connected flash (erase/program/verify), not for normal XiP bring-up.
- Implement RTL in **IEEE Verilog-2005** (`*.v`), **vendor-agnostic** (programmable opcodes, dummy, continuous policy).
- Verify with **pluggable flash behavioral models** (examples in-repo: `sst26wf080b.v`, `s28hs256m4.sv` — not sole targets).

### 1.2 Non-goals (v1)

- Any other C–A–D widths: **no 1-1-2, 1-2-2, 1-1-4, 4-4-4/QPI**, dual-only, etc.
- **1-1-1 DTR** (DTR only paired with 1-4-4).
- Hard-coding one flash vendor’s register map into the XiP data path (device bring-up via SW bit-bang / CSRs only).
- Hardware flash program/erase state machines — array programming is **SW bit-bang only**.
- Using bit-bang for routine boot configuration (see §7.6).
- Cache coherency protocol (snooping / MESI); see §6.
- Writeable XiP, write-allocate, or dirty lines.
- DMA, multi-outstanding AHB transactions, or AHB-full (only AHB-Lite).
- Synthesizable SystemVerilog (RTL is Verilog-2005 only; SV is allowed in TB + some vendor models).

---

## 2. System context

### 2.1 CPU / bus

| Property | Value |
|----------|--------|
| Address width (CPU AHB) | 16-bit (`HADDR[15:0]`) |
| Data width (CPU AHB) | 16-bit |
| Main memory fabric | AHB-Lite |
| Peripheral fabric | APB (via AHB→APB bridge in MMIO region) |
| Flash physical address (controller) | **20-bit** byte address (`phys[19:0]`) → **1 MB** window |
| Example flash VIPs | Microchip **SST26WF080B** (1 MB); Infineon **S28HS256M4** (32 MB model, low 1 MB used) |
| SPI address cycles | **24-bit** default (`spi_addr = {4'b0, phys[19:0]}`); optional 32-bit later |

### 2.2 System memory map (CPU view)

| Region | Range | Size | Backend | Bus path |
|--------|-------|------|---------|----------|
| Fixed XiP | `0x0000`–`0x3FFF` | 16 KB | SPI/QSPI flash (fixed page) | AHB → XIP → flash |
| SRAM | `0x4000`–`0x7FFF` | 16 KB | On-chip SRAM | AHB → SRAM |
| Paged window | `0x8000`–`0xBFFF` | 16 KB | Flash **or** PSRAM (mux) | AHB → page mux → XIP/PSRAM |
| MMIO / VRAM | `0xC000`–`0xFFFF` | 16 KB | Peripherals, CSRs, VRAM | AHB → APB / dedicated |

The XIP controller participates only in **flash-backed** accesses (fixed window always; paged window when target = flash). Protocol on the wire is **SPI or QSPI** per `XIP_MODE` (§7).

### 2.3 High-level block diagram

```
                    CPU AHB-Lite (16-bit addr/data)
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
         [decode]        [SRAM]          [APB bridge]
              │                               │
     fixed / paged                            │
     flash selects                            ▼
              │                      XIP APB CSR + bit-bang
              ▼                               │
     ┌─────────────────┐                      │
     │ Page mux / map  │  phys[19:0]          │
     │ (sysctrl or XIP)│──────────────────┐   │
     └────────┬────────┘                  │   │
              │ xip_sel + phys            │   │
              ▼                           ▼   ▼
     ┌────────────────────────────────────────────┐
     │              XIP Controller                  │
     │  ┌──────────┐  ┌──────────┐  ┌────────────┐ │
     │  │ AHB RO   │  │ RO cache │  │ Fill FSM   │ │
     │  │ slave    │──│ 256 B    │──│ SPI / QSPI │ │
     │  └──────────┘  └──────────┘  └──────┬─────┘ │
     │                                     │       │
     │               pin mux (XIP vs BB) ──┴──     │
     └─────────────────────┬───────────────────────┘
                           ▼
                  CS#, SCK, IO[3:0]
                      SPI NOR
```

---

## 3. Address mapping

### 3.1 Window offset

Both flash-facing CPU regions are **16 KB**. Only **14 bits** of byte offset are used for the flash address:

```
offset[13:0] = HADDR[13:0]
```

`HADDR[15:14]` select the **region** (and routing). They are **not** folded into `phys` unless explicitly specified by a future extension.

### 3.2 Physical address (20-bit)

Flat flash byte address:

```
phys[19:0] = { page[5:0], offset[13:0] }
```

| Field | Bits | Meaning |
|-------|------|---------|
| `offset` | `[13:0]` | Byte offset within 16 KB window |
| `page` | `[5:0]` | 16 KB page index |
| **Total** | **20** | **1 MB** addressable flash |

SPI NOR command cycles use a **24-bit** address field with the upper nibble zero:

```
spi_addr[23:0] = { 4'b0000, phys[19:0] }
```

### 3.3 Fixed XiP window (`0x0000`–`0x3FFF`)

Always routed to QSPI XIP when the controller is enabled.

```
phys = { FIXED_PAGE[5:0], HADDR[13:0] }
```

| Parameter | Reset default | Notes |
|-----------|---------------|--------|
| `FIXED_PAGE` | `0` | Boot image at bottom of flash; optionally CSR-writable and lockable |

No software page setup is required for reset fetch from `0x0000`.

### 3.4 Paged window (`0x8000`–`0xBFFF`)

Routed by a **page mux** (sysctrl and/or XIP-adjacent logic):

| `PAGE_TARGET` | Destination |
|---------------|-------------|
| `FLASH` | XIP controller with `phys = { PAGE_SEL[5:0], HADDR[13:0] }` |
| `PSRAM` | PSRAM controller (outside this spec); **must not** enter XIP cache |

`PAGE_SEL` and `PAGE_TARGET` may live in system control MMIO; the XIP engine consumes the resulting **select + `phys`** (or equivalent page + offset).

### 3.5 Decode / routing requirements

Address decode and routing **must**:

1. Assert XIP select only for **flash-backed** accesses.
2. Present a stable **`phys[19:0]`** (or page + offset) with each accepted XIP access.
3. Sample page registers when the access is accepted so lookup tag and fill address match.
4. Never present SRAM, PSRAM, or MMIO traffic to the XIP cache.

---

## 4. AHB-Lite interface (XiP data path)

### 4.1 Role

Single **AHB-Lite slave** port for CPU instruction/RO-data fetch from flash-backed regions (as selected by the interconnect).

### 4.2 Attributes

| Signal / behavior | Requirement |
|-------------------|-------------|
| Data width | 16-bit |
| Address | 16-bit `HADDR` (region decode may be external; see §3) |
| Transfers | Single / sequential AHB-Lite; no burst length requirement beyond Lite |
| `HSIZE` | Byte and halfword only |
| `HWRITE` | **Reads only** for success path |
| Writes | Respond with **`HRESP = ERROR`** (recommended) or documented ignore; no cache update |
| Wait states | `HREADY` low for miss / fill / flash busy as needed |
| Error | Optional timeout sticky status; ERROR response policy documented in CSR |

### 4.3 Sideband (implementation choice)

Either:

- **A.** Interconnect supplies `xip_sel` + `phys[19:0]`, or  
- **B.** XIP slave decodes `HADDR` and reads `FIXED_PAGE` / `PAGE_*` internally.

Behavior must be equivalent to §3.

### 4.4 Outstanding transactions

v1: **one** outstanding miss fill at a time (plus optional limited prefetch; see §5.5). AHB master is stalled with wait states.

---

## 5. Read-only cache

### 5.1 Organization

| Parameter | Value |
|-----------|--------|
| Total capacity | **256 bytes** |
| Lines | **16** |
| Line size | **16 bytes** |
| Associativity | **Direct-mapped** (v1) |
| Policy | **Read-only**; allocate on miss fill |
| Write | N/A (no store path) |

### 5.2 Address fields (physical)

```
phys[19:0]
  [3:0]   line offset (16-byte line)
  [7:4]   index (16 lines)
  [19:8]  tag (12 bits)
```

Each line stores: `{ valid, tag[11:0], data[127:0] }`.

### 5.3 Lookup

```
hit = valid[index] && (tag[index] == phys[19:8])
```

**The cache always keys on full `phys[19:0]`**, never on raw `HADDR` alone.

### 5.4 Miss fill

1. On miss, request a **16-byte** aligned line at `phys & ~14'hF` from the **fill engine** (SPI or QSPI path per `XIP_MODE`).
2. **Critical halfword first** (recommended): return the requested 16-bit beat to AHB as soon as available; complete the line fill before installing / while streaming.
3. Install line with `valid=1` and tag = `phys[19:8]`.

### 5.5 Prefetch (recommended)

- After a demand fill (or on sequential hint), optionally prefetch **`phys + 16`** if it remains inside the **same 16 KB window** (no `offset` overflow).
- Do **not** auto-increment `page` on window wrap.
- Prefetch must use the same phys tagging rules; cancel/complete cleanly if page mapping changes mid-prefetch.

### 5.6 Invalidate

| Trigger | Action |
|---------|--------|
| CSR `CACHE_INV` | All lines `valid=0` |
| Soft reset / XIP disable sequence | Invalidate |
| After flash program/erase (SW) | SW must pulse `CACHE_INV` |

No invalidate required on `PAGE_SEL` change when tags include page bits in `phys`.

---

## 6. Cache identity (no coherency protocol)

### 6.1 Principle

With:

- read-only allocation,
- a single flash fill engine (SPI or QSPI mode),
- **full 20-bit physical tags**,
- exclusive decode so only flash XiP enters the cache,

there is **no hardware cache coherency protocol**. Correctness is an **invariant** of addressing and routing.

**Mode / rate switch (SPI ↔ QSPI, SDR ↔ DTR):** SW must **invalidate the cache** after changing `XIP_MODE` or `DTR_EN` (and exit continuous if leaving QSPI or changing rate). Data identity is unchanged; invalidation avoids any partially observed line during the protocol change.

### 6.2 Consequences

| Scenario | Behavior |
|----------|----------|
| Same `phys` via fixed and paged windows | One cache line; correct sharing |
| Different `PAGE_SEL` | Different `phys` → no false hit |
| `PAGE_TARGET = PSRAM` | Traffic never enters XIP cache |
| Flash content changed (ISP) | SW invalidate after program |

### 6.3 Explicit non-requirements

- No flush-on-page-change.
- No snooping of APB bit-bang.
- No PSRAM↔XIP cache linkage.

---

## 7. Flash fill engine (1-1-1 SDR, 1-4-4 SDR, 1-4-4 DTR)

The hardware fill engine supports **exactly two I/O-width modes** (`XIP_MODE`) and, for 1-4-4 only, **SDR or DTR** (`DTR_EN`).

**Reset default: 1-1-1 SDR.** Software may later switch to **1-4-4 SDR** or **1-4-4 DTR** for performance.

### 7.0 Transaction shape

Each **cache line fill** is one or more `CS#`-framed SPI transactions. Default shape:

```text
CS# low → [command?] → [address] → [mode?] → [latency] → [16 bytes data] → CS# high
```

| Term | Meaning |
|------|---------|
| **Full-command fill** | Every fill sends opcode (`CONT_EN=0`, or first fill after exit). Safe for all parts. |
| **Command-less continuous** | After enter with mode-stay, later fills omit opcode (`CONT_EN=1`). Supported by e.g. **SST26** (`Mode_Configuration[7:4]=0xA`); **not** used on S28HS-class models that re-require opcode each `CS#`. |
| **Streaming within CS#** | Keep clocking until 16 B captured. |

CSR **`CONT_EN`** selects policy. SW programs mode-stay/exit patterns per vendor (§17).

### 7.1 Mode summary (normative)

Notation:

- **C–A–D** = I/O width of **Command – Address – Data**.
- **S / D** = **Single** / **Double** Transfer Rate (JEDEC **1S-4D-4D** for quad DTR).

| `XIP_MODE` | `DTR_EN` | Name | Protocol | Default opcode | Typical use |
|------------|----------|------|----------|----------------|-------------|
| `0` | *ignored* | **SPI XiP** | **1-1-1 SDR** | `0x0B` (opt. `0x03`) | **Reset / boot** |
| `1` | `0` | **QSPI SDR** | **1-4-4 SDR** | `0xEB` | Steady-state quad |
| `1` | `1` | **QSPI DTR** | **1S-4D-4D** | `0xED` | Highest bandwidth (if part supports) |

Opcodes, dummy, mode bytes, and continuous policy are **CSR-programmable** so the same RTL works with different VIPs/parts (§17).

| Explicitly **not** supported | Notes |
|------------------------------|--------|
| 1-1-2 / 1-2-2 | Dual modes |
| 1-1-4 | Quad Output only (`0x6B`) as XiP path |
| 4-4-4 / QPI command phase | Optional device EQIO/SQI may be enabled via **bit-bang**, not as a third XiP C–A–D mode in v1 |
| 1-1-1 DTR | DTR only with 1-4-4 |

### 7.2 SPI XiP mode (`XIP_MODE = 0`) — reset default — **1-1-1 SDR**

| Item | Specification |
|------|----------------|
| I/O | **1-1-1 SDR** (IO0 MOSI, IO1 MISO) |
| Command | **`0x0B` Fast Read** (default). Optional **`0x03` Read** via `SPI_CMD` |
| Address | 24-bit SDR, `{4'b0, phys[19:0]}` (or truncated per `ADDR_BYTES`) |
| Dummy | Programmable (`DUMMY`); 0 for `0x03` |
| Continuous | N/A (always full command) |
| CS# | Per fill |

### 7.3 QSPI SDR mode (`XIP_MODE = 1`, `DTR_EN = 0`) — **1-4-4 SDR**

| Item | Specification |
|------|----------------|
| Command | Default **`0xEB`** on IO0, **1S** (omitted when continuous active and `CONT_EN`) |
| Address | **4S** — 24-bit → **6 SCK** (3-byte) |
| Mode byte | Optional phase (`MODE_PHASE_EN`): e.g. SST26 mode config; send `MODE_STAY` / `MODE_EXIT` |
| Latency | **`DUMMY` SCK** after mode (or after addr if no mode phase) |
| Data | **4S** — 16 B → **32 SCK** |

### 7.4 QSPI DTR mode (`XIP_MODE = 1`, `DTR_EN = 1`) — **1S-4D-4D**

| Item | Specification |
|------|----------------|
| Command | Default **`0xED`**, **1S** (if part supports; else leave `DTR_EN=0`) |
| Address | **4D** — 24-bit → **3 SCK** |
| Mode / latency / data | DTR on multi-line phases; `DUMMY` in SCK cycles |
| DS | Optional strobe pad; v1 may sample from SCK |

`DTR_EN=1` with `XIP_MODE=0` is ignored.

### 7.5 Fill FSM states

| State | Description |
|-------|-------------|
| `IDLE` | `CS#` high |
| `CMD` | Shift opcode (skipped if continuous active) |
| `ADDR` | Address phase |
| `MODE` | Optional mode byte(s) |
| `LAT` | Dummy/latency |
| `DATA` | Capture 16 B |
| `DONE` | `CS#` high; update continuous sticky flag from mode pattern |

**`CONT_EN=0`:** always `CMD` each fill (portable).  
**`CONT_EN=1`:** after successful enter with `MODE_STAY`, subsequent fills skip `CMD` until `EXIT_CONT` / mode-exit / mode change / disable.

### 7.6 Software mode switches

Run critical steps from **SRAM** if fetches would race the switch.

**A. SPI → QSPI SDR (1-4-4)**

1. Ensure flash is ready for quad I/O (S28HS: device config / CFR as required; no classic “QE bit only” Winbond path assumed).  
2. Wait `BUSY==0`.  
3. Program `DUMMY` / `CLKDIV` for `0xEB` (match CFR2 latency).  
4. `DTR_EN=0`, `XIP_MODE=1`, `CACHE_INV`.  
5. Next miss uses full `0xEB` transactions.

**B. → QSPI DTR (1S-4D-4D)**

1. Device supports `0xED`.  
2. Wait `BUSY==0`.  
3. Program `DUMMY` / `CLKDIV` / optional `DTR_PHY`.  
4. `XIP_MODE=1`, `DTR_EN=1`, `CACHE_INV`.

**C. QSPI → SPI (before ISP)**

`DTR_EN=0` → `XIP_MODE=0` → `CACHE_INV` → optional `XIP_EN=0` / `BB_EN=1`.

### 7.7 Clocking and rate

- `CLKDIV`: SCK period vs controller clock for the HW engine.  
- SPI Mode 0 (CPOL=0, CPHA=0) baseline for **SDR** command and 1-1-1.  
- **DTR:** SCK still a single clock; **IO launch/capture on rising and falling edges** during 4D phases.  
- Reset `CLKDIV` should be conservative for 1-1-1 boot; SW may reduce divisor after switching to QSPI/DTR if timing allows.  
- Max `f_sck` is board + flash + PHY limited (DTR usually stricter than SDR at the same pin rate).

### 7.8 Pads and DTR PHY requirements

| Item | Requirement |
|------|-------------|
| Pad type | **Single-ended push-pull** bidirectional on `IO[3:0]`; push-pull `SCK`, `CS#` |
| OE | Drive during cmd (IO0) / addr / mode; **Hi-Z** before data phase with safe turnaround |
| SDR capture | Sample on appropriate SCK edge (mode 0) |
| DTR capture | Sample **both** edges during 4D data (and align addr launch on both edges) |
| Turnaround | Programmable gap or fixed 1/2 SCK if required by flash between last mode/dummy and first data |
| Optional CSR | `DTR_SAMP_DLY` / phase select if the FPGA/ASIC needs IO delay taps for timing closure |
| Bit-bang | SDR-only edge control; not used for DTR traffic |

DTR does **not** require open-drain or differential pads.

### 7.9 First miss vs later fills

**All modes (v1):** every fill is a **full** command + address + latency + 16 B data transaction.  
There is no abbreviated command-less fill.

---

## 8. APB CSR and bit-bang interface

### 8.1 Role

Second slave port: **APB** for:

| Function | Use |
|----------|-----|
| Mode / timing CSRs | `XIP_MODE`, `DUMMY`, `CLKDIV`, continuous mode bits, enables |
| Cache control / status | Invalidate, busy, errors |
| **Bit-bang SPI** | **Only for programming** the connected flash (erase, program, verify, and any one-time status/QE setup done in that session) |

Bit-bang is **not** required to start XiP: after reset the controller fetches in **SPI XiP** via the hardware fill engine.

Mapped in system **MMIO** (`0xC000`–`0xFFFF`) via AHB→APB. Exact base address is integration-defined (recommend a fixed slice, e.g. `0xC100`).

### 8.2 Bus attributes

| Property | Value |
|----------|--------|
| Protocol | APB3-style (or simpler APB with `PSEL`/`PENABLE`) |
| Data width | **16-bit** (preferred, matches CPU) unless SoC APB is globally 32-bit |
| Wait states | Normally zero; implementation may stretch `PREADY` |

### 8.3 Pin ownership mutex

Exactly **one** owner of `CS#`, `SCK`, `IO[3:0]`:

| Mode | Condition | Owner |
|------|-----------|--------|
| XiP | `XIP_EN=1` | Fill FSM (1-1-1 / 1-4-4 SDR / 1-4-4 DTR) + cache |
| Bit-bang | `XIP_EN=0` | APB bit-bang registers (**programming only**, SDR) |

**Rules:**

1. While `XIP_EN=1`, bit-bang pad writes are **ignored** or return APB error (choose one; document).  
2. Before **programming** (ISP): SW runs from **SRAM**, sets `XIP_EN=0`, **invalidates cache**, then bit-bangs erase/program/verify.  
3. After ISP: `BB_EN=0`, `CACHE_INV`, set `XIP_MODE` / `DTR_EN` / `DUMMY`, `XIP_EN=1`.  
4. Normal boot does **not** use bit-bang: reset → **1-1-1 SDR** → optional SW switch to **1-4-4 SDR or DTR** (§7.6).

### 8.4 Register map (logical)

Addresses are **byte offsets** from the XIP APB base; 16-bit access aligned. Exact numeric map may be refined in RTL headers; names and fields are normative for v1.

#### 8.4.1 `CTRL` — offset `0x00`

| Bits | Name | Reset | Description |
|------|------|-------|-------------|
| 0 | `XIP_EN` | 1* | 1 = hardware XiP path may run fills (*integration may use 1 for boot-from-flash) |
| 1 | `BB_EN` | 0 | 1 = bit-bang drives pads (only if `XIP_EN=0`); **programming only** |
| 2 | `CACHE_INV` | 0 | Write 1: invalidate all lines (self-clearing) |
| 3 | `CONT_EN` | 0 | 1 = allow command-less continuous on QSPI after mode-stay |
| 4 | `EXIT_CONT` | 0 | Write 1: force continuous inactive; next fill sends full command (self-clearing) |
| 5 | `SOFT_RST` | 0 | Write 1: reset XIP FSMs, invalidate cache (self-clearing) |
| 6 | `XIP_MODE` | **0** | **0 = 1-1-1 SPI; 1 = 1-4-4 QSPI** |
| 7 | `DTR_EN` | **0** | **0 = SDR; 1 = DTR (only if `XIP_MODE=1`)** |
| 8 | `MODE_PHASE_EN` | 0 | 1 = insert mode-byte phase on QSPI fills (e.g. SST26) |
| 10:9 | `SPI_CMD` | 0 | `00` = `0x0B`; `01` = `0x03` (**1-1-1 only**) |
| 11 | `PREFETCH_EN` | **1** | 1 = next-line prefetch within 16 KB window |

#### 8.4.2 `STATUS` — offset `0x02`

| Bits | Name | Description |
|------|------|-------------|
| 0 | `BUSY` | Fill, enter, or exit in progress |
| 1 | `CONT_ACTIVE` | 1 if command-less continuous session is active |
| 2 | `XIP_EN_STS` | Effective XiP enable |
| 3 | `BB_ACTIVE` | Bit-bang owns pads |
| 4 | `ERR` | Sticky error (timeout / illegal); W1C via `STATUS` or `ERR_CLR` |
| 5 | `XIP_MODE_STS` | 0=**1-1-1**, 1=**1-4-4** |
| 6 | `DTR_STS` | Effective DTR enable (0 if SPI or DTR off) |

#### 8.4.3 `CLKDIV` — offset `0x04`

| Bits | Name | Description |
|------|------|-------------|
| 7:0 | `DIV` | SCK period divisor for HW engine (`0` = invalid or bypass per RTL) |

#### 8.4.4 `DUMMY` — offset `0x06`

| Bits | Name | Description |
|------|------|-------------|
| 5:0 | `CYCLES` | Latency **SCK cycles** after address/mode. **Vendor profile** sets this (see §17). Reset default **8** (typical Fast Read). |

#### 8.4.5 `MODE_STAY` / `MODE_EXIT` — offsets `0x08` / `0x0A`

| Reg | Bits | Description |
|-----|------|-------------|
| `MODE_STAY` | 7:0 | Mode pattern to **enter/keep** continuous (e.g. SST26 `0xAx` family; model checks `[7:4]==0xA`) |
| `MODE_EXIT` | 7:0 | Mode pattern to **leave** continuous (e.g. not `0xAx`) |

Used only when `MODE_PHASE_EN=1`.
#### 8.4.6a `QSPI_CMD` — offset `0x0E` (optional packed with neighbors in RTL)

| Bits | Name | Reset | Description |
|------|------|-------|-------------|
| 7:0 | `CMD_SDR` | `0xEB` | Opcode for 1-4-4 **SDR** fill |
| 15:8 | `CMD_DTR` | `0xED` | Opcode for 1-4-4 **DTR** fill |

#### 8.4.6b `DTR_PHY` — offset `0x14` (optional)

| Bits | Name | Description |
|------|------|-------------|
| 3:0 | `SAMP_DLY` | Input sample delay taps / phase select for DTR capture (implementation-defined) |
| 4 | `SAMP_EDGE_INV` | Optional invert dual-edge sample alignment |

#### 8.4.7 `FIXED_PAGE` — offset `0x0C`

| Bits | Name | Description |
|------|------|-------------|
| 5:0 | `PAGE` | Page index for fixed window `0x0000`–`0x3FFF` |
| 15 | `LOCK` | Optional: when 1, ignore further writes to `FIXED_PAGE` |

*(If page mux lives entirely in sysctrl, this register may be a read-only mirror or omitted; fixed mapping must still default to page 0 at reset.)*

#### 8.4.8 Bit-bang: `BB_CTRL` — offset `0x10`

| Bits | Name | Description |
|------|------|-------------|
| 0 | `CS_N` | Chip select (1 = deasserted/high) |
| 1 | `SCK` | Clock pad level |
| 5:2 | `OE` | Output enable for `IO[3:0]` (1 = drive) |
| 7:6 | Reserved | |

#### 8.4.9 `BB_IO` — offset `0x12`

| Bits | Name | Description |
|------|------|-------------|
| 3:0 | `OUT` | Output data when OE=1 |
| 7:4 | `IN` | Read: sampled pad levels (RO nibble; or separate `BB_IN`) |

SW bit-bangs SPI by sequencing `CS_N`, `OE`, `OUT`, and `SCK` edges under `BB_EN`.

### 8.5 Bit-bang usage (informative) — programming only

Bit-bang is for **array programming / ISP** (and related status ops in that session), not for everyday XiP mode control.

Typical 1-1-1 ISP flow (SW):

1. Copy needed code to SRAM and jump there.  
2. `EXIT_CONT` if QSPI continuous was active; `XIP_MODE` may stay or return to SPI.  
3. `XIP_EN=0`; `BB_EN=1`; `CACHE_INV`.  
4. Bit-bang `RDSR` / `WREN` / `SE` / `PP` / WIP poll / verify; optional set QE for later QSPI.  
5. `BB_EN=0`; `CACHE_INV`; set `XIP_MODE` (0 SPI or 1 QSPI); `XIP_EN=1`; if QSPI, optional `ENTER_CONT`.

Most ISP stays on IO0/IO1 (standard SPI bit-bang).

### 8.6 What APB does **not** do

- Serve cache line data for fetch.
- Participate in AHB XiP hit path.
- Implement multi-master coherency with the cache.

---

## 9. Software model

### 9.1 Memory usage

| Content | CPU region |
|---------|------------|
| Reset vectors, ISRs stubs, resident runtime, page trampoline | Fixed XiP `0x0000`–`0x3FFF` (typically flash page 0) |
| Stack, heap, RW data | SRAM `0x4000`–`0x7FFF` |
| Overlays, assets, extended code/RO | Paged `0x8000`–`0xBFFF` via `PAGE_SEL` |
| XIP CSRs, page mux, other IO | `0xC000`–`0xFFFF` |

### 9.2 Page flip

- Change `PAGE_SEL` only from code not dependent on the paged window (fixed flash or SRAM).  
- Cache need not be flushed (phys tags).  
- Prefetch should not cross the 16 KB window.

### 9.3 Linker / images

- Distinguish **VMA** (CPU addresses in windows) from **LMA / phys** (flash page + offset).  
- Build system places boot image at `phys` page 0 by default.

---

## 10. Reset and boot

| Item | Behavior |
|------|----------|
| `XIP_MODE` | **0 — 1-1-1 SDR** (`0x0B` or `0x03`) |
| `DTR_EN` | **0** |
| `FIXED_PAGE` | 0 |
| Cache | All invalid |
| QSPI continuous | Inactive |
| `XIP_EN` | Prefer **1** out of reset for ROM-less boot-from-flash |
| Bit-bang | Off; not used for boot |
| First miss | **1-1-1 SDR** line fill |
| Later (optional) | SW → **1-4-4 SDR** (`0xEB`) and/or **1-4-4 DTR** (`0xED`) per §7.6 |
| Default `DUMMY` | Compatible with SPI Fast Read; retune before QSPI |

**Boot narrative:** CPU fetches in **1-1-1 SDR** (`0x0B`/`0x03`). SW may switch to full-transaction **1-4-4** `0xEB` then optional **DTR** `0xED` after programming latency to match the flash.

---

## 11. Error handling

| Condition | Response |
|-----------|----------|
| AHB write to XIP window | `HRESP=ERROR` (recommended) |
| Access while `XIP_EN=0` | ERROR or interconnect does not select XIP |
| Flash timeout (optional counter) | Sticky `STATUS.ERR`; complete AHB with ERROR |
| BB while `XIP_EN=1` | Ignore BB or APB error |

---

## 12. Performance targets (informative)

| Path | Target |
|------|--------|
| Cache hit | 0–1 wait state |
| Cache miss, 1-1-1 SDR | Full SPI line fill; lowest bandwidth |
| Cache miss, 1-4-4 SDR (`0xEB`) | ~4× SPI data phase; critical halfword first recommended |
| Cache miss, 1-4-4 DTR (`0xED`) | ~2× SDR quad data phase at same `f_sck` |
| Sequential code | Prefetch aims to hide next-line miss latency |

Exact cycle counts depend on `CLKDIV`, dummy, SDR vs DTR, and `f_clk`.

---

## 13. Key decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | 16-bit AHB-Lite RO XiP + 16-bit APB CSR | Matches CPU; separates fetch vs admin |
| 2 | 20-bit physical flash address | 1 MB space with 16 KB windows (6-bit page + 14-bit offset) |
| 3 | Fixed 16 KB + paged 16 KB map | Boot resident + overlays; matches system map |
| 4 | RO cache 16×16 B, direct-mapped, phys-tagged | Small, correct across aliases/pages |
| 5 | No coherency protocol | RO + full phys tags + exclusive routing |
| 6 | I/O widths = **1-1-1 and 1-4-4 only** | Minimal width set |
| 7 | Rates = **SDR** on both; **DTR only on 1-4-4** (1S-4D-4D) | Boot simple; optional max bandwidth |
| 8 | Reset **1-1-1 SDR**; SW → `0xEB` / `0xED` | Safe boot; staged performance |
| 9 | Optional **command-less continuous** via `CONT_EN` + mode phase | SST26 yes; S28HS profile leaves off |
| 10 | DTR optional on 1-4-4 (push-pull dual-edge PHY) | When VIP/part supports `0xED` |
| 11 | APB bit-bang **only for flash programming** (SDR) | ISP; not required for XiP start |
| 12 | Exclusive pin mux (`XIP_EN` / `BB_EN`) | Prevent pad fights |
| 13 | Prefetch within 16 KB window only | Simple; no silent page cross |
| 14 | Decode builds `phys` before cache | Single identity for hit/fill |
| 15 | Cache inv on `XIP_MODE` / `DTR_EN` / continuous policy change | Clean handoff |
| 16 | RTL = **Verilog-2005**; **pluggable** flash VIPs | SST26 + S28HS examples, more later |

---

## 14. Implementation checklist

- [ ] AHB-Lite RO slave + wait-state miss path  
- [ ] Phys construction (fixed + paged) and interconnect select  
- [ ] Cache tags/data arrays + inv  
- [ ] **1-1-1 SDR** fill vs VIP profile  
- [ ] **1-4-4 SDR** `0xEB` (+ mode phase / continuous optional)  
- [ ] **1-4-4 DTR** `0xED` where profile enables  
- [ ] Cache + AHB-Lite RO slave  
- [ ] APB CSR + bit-bang mux  
- [ ] TB profiles: at least **sst26** and **s28hs** (§17)  
- [ ] Prefetch (optional phase)  

---

## 15. Open integration parameters

These are SoC-specific and must be fixed at integration time:

| Parameter | Options |
|-----------|---------|
| XIP APB base address | Within `0xC000`–`0xFFFF` |
| `XIP_EN` out of reset | Prefer 1 (boot-from-flash in SPI mode) |
| Page mux location | Sysctrl vs inside XIP APB |
| `PAGE_SEL` register address | Sysctrl map |
| Flash vendor defaults | `DUMMY` for SPI / QSPI SDR / QSPI DTR; `MODE_STAY`/`EXIT` |
| Default SPI command | `0x0B` vs `0x03` |
| DTR opcode | Default `0xED`; vendor alternate |
| DTR PHY | Need for `SAMP_DLY` / board timing budget |
| Write/`BB` error response style | ERROR vs ignore |
| QE at manufacturing | Assumed set before first QSPI switch, or set via BB from SRAM |

---

## 17. Flash verification models (pluggable VIPs)

The controller RTL is **not** tied to one flash. In-repo models are **examples** used by the TB via a thin adapter (pin map + profile). Add more parts by dropping a model + profile, not by forking the controller.

### 17.1 Common VIP interface (controller view)

| Controller | Meaning |
|------------|---------|
| `spi_sck` | Serial clock |
| `spi_cs_n` | Active-low chip select |
| `spi_io[3:0]` | Bidirectional data (push-pull + OE) |
| `spi_reset_n` | Optional; tied high if part has no RESET# |
| `spi_ds` | Optional DTR strobe; float if unused |

### 17.2 Example A — Microchip SST26WF080B (`sst26wf080b.v`)

| Item | Value |
|------|--------|
| File | `sst26wf080b.v` (Verilog; common core `sst26wfxxxb`) |
| Density | **1 MB** (`ADDR_MSB=19`) — matches controller `phys[19:0]` exactly |
| Ports | `SCK`, `SIO[3:0]`, `CEb` |
| Timescale | `1ns / 10ps` |
| Preload | After t>0: `$readmemh(..., I0.memory, ...)` |

**Pin adapter**

| Controller | SST26 |
|------------|--------|
| `spi_sck` | `SCK` |
| `spi_cs_n` | `CEb` |
| `spi_io[3:0]` | `SIO[3:0]` |
| `spi_reset_n` | *(none — tie unused)* |
| `spi_ds` | *(none)* |

**Opcode / feature profile (XiP)**

| Feature | SST26 |
|---------|--------|
| SPI read | `0x03` (`SPI_READ`) |
| SPI fast read | `0x0B` (`SPI_HS_READ`) |
| Quad I/O read | `0xEB` (`SPI_QUAD_IO_READ`) — requires **IOC=1** (I/O configuration) |
| Command-less continuous | **Yes** — mode config nibble high = `0xA` (`Mode_Configuration[7:4]`) |
| Enter SQI bus mode | `0x38` `EQIO` (bit-bang / SW; not required for SPI-mode `0xEB` if IOC set) |
| DTR `0xED` | Not primary for this VIP (leave `DTR_EN=0` unless validated) |

**Suggested CSR profile for SST26**

| CSR | Suggested value |
|-----|-----------------|
| `DUMMY` (0x0B) | per datasheet / model (HS read dummy clocks) |
| `DUMMY` (0xEB) | match model (mode + dummy nibbles after addr) |
| `MODE_PHASE_EN` | **1** |
| `MODE_STAY` | e.g. `0xA0` (high nibble `A`) |
| `MODE_EXIT` | e.g. `0x00` |
| `CONT_EN` | **1** once continuous is desired |
| `DTR_EN` | **0** for default SST26 suite |

### 17.3 Example B — Infineon S28HS256M4 (`s28hs256m4.sv`)

| Item | Value |
|------|--------|
| File | `s28hs256m4.sv` (SystemVerilog) |
| Density | 256 Mbit / **32 MB** model; controller uses low **1 MB** (`phys` zero-extends into 24-bit addr) |
| Ports | `SI, SO, DQ2, DQ3, SCK, CSNeg, DS, RESETNeg, INTNeg` |
| Timescale | **1 ps / 1 ps** required |

**Pin adapter**

| Controller | S28HS |
|------------|--------|
| `spi_io[0]` | `SI` |
| `spi_io[1]` | `SO` |
| `spi_io[2]` | `DQ2` |
| `spi_io[3]` | `DQ3` |
| `spi_sck` | `SCK` |
| `spi_cs_n` | `CSNeg` |
| `spi_reset_n` | `RESETNeg` |
| `spi_ds` | `DS` (optional) |

**Opcode map**

| Opcode | Model instruction | Notes |
|--------|-------------------|--------|
| `0x03` | `RDAY1_C_0` | 1-1-1 |
| `0x0B` | `RDAY2_C_0` | latency from CFR2 |
| `0xEB` | `RDAY5_C_0` | 1-4-4 SDR |
| `0xED` | `RDAY7_C_0` | 1S-4D-4D |

**Suggested CSR profile for S28HS (default CFR2V=`0x08`)**

| CSR | Suggested value |
|-----|-----------------|
| `DUMMY` for `0x0B` | **8** |
| `DUMMY` for `0xEB`/`0xED` | **20** (mapped latency table) |
| `MODE_PHASE_EN` | **0** (no Winbond/SST mode-byte phase on this path) |
| `CONT_EN` | **0** (model expects opcode each `CS#`) |
| `DTR_EN` | optional **1** for `0xED` tests |

Do **not** enable device QPI (`CFR5`) for this controller’s 1-line command path.

### 17.4 Profile table (summary)

| Profile | Model file | Lang | CONT_EN | MODE_PHASE | DTR suite | Density vs phys |
|---------|------------|------|---------|------------|-----------|-----------------|
| `sst26` | `sst26wf080b.v` | Verilog | yes | yes | no (default) | 1 MB = full map |
| `s28hs` | `s28hs256m4.sv` | SV | no | no | yes | 1 MB window into 32 MB |

### 17.5 TB requirements

1. Compile **one VIP per run** (or separate TB tops): e.g. `tb_xip_sst26`, `tb_xip_s28hs`.  
2. Apply matching **CSR profile** before XiP traffic.  
3. Preload VIP memory with known pattern; scoreboard from same image.  
4. Common tests: 1-1-1 boot, switch to 1-4-4, cache hit/miss, page_sel, write ERROR, BB mutex.  
5. Profile-specific: SST26 continuous omit-cmd; S28HS DTR `0xED`.  
6. RTL lint: `iverilog -g2005` on `rtl/*.v` (no VIP required).  
7. Full co-sim: any simulator that accepts the VIP language (iverilog often OK for SST26; SV tools for S28HS).

Detailed tasks: **`RTL_PLAN.md`**.

---

## 18. Document history

| Rev | Date | Notes |
|-----|------|--------|
| 0.1 | 2026-07-13 | Initial spec from architecture discussion |
| 0.2 | 2026-07-13 | Reset = SPI XiP; SW switch to QSPI `0xEB`; bit-bang = programming only |
| 0.3 | 2026-07-13 | Lock I/O widths to **1-1-1 and 1-4-4 only** |
| 0.4 | 2026-07-13 | Add **1-4-4 DTR** (1S-4D-4D, `0xED`); `DTR_EN` + PHY notes |
| 0.5 | 2026-07-13 | S28HS notes; Verilog-2005 RTL plan |
| 0.6 | 2026-07-13 | Pluggable VIPs: SST26 + S28HS examples; optional continuous + mode phase |
