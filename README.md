# ZXip

**ZXip** is a small **execute-in-place (XiP) QSPI flash controller** for AHB-Lite SoCs.

It targets instruction and RO-data fetch from SPI/QSPI NOR flash with a line cache,
optional next-line prefetch, continuous mode, and an APB CSR + bit-bang path for
device bring-up (e.g. program, status, mode switch).

| | |
|--|--|
| Host bus | **AHB-Lite** RO slave, **`HOST_DW` = 16 (default) or 32**, **`HOST_AW` = 16 or 32** |
| CSRs | **16-bit APB** |
| Flash | SPI 1-1-1 (`0x0B` / `0x03`) and QSPI 1-4-4 (`0xEB`) |
| Cache | Parameterized lines × bytes (8/16 × 8/16), default 16×16 B |
| RTL | IEEE Verilog-2005 |
| License | Apache-2.0 |

**RV32:** instantiate `zxip_top #(.HOST_DW(32), .HOST_AW(32))`. Flat phys uses `HADDR[19:0]` when `phys_valid=0` (fabric `HSEL` defines the aperture).  
**ZX16 / 16-bit:** leave defaults (`HOST_DW=16`, `HOST_AW=16`) with the fixed/paged window decode.  
**SoC integration:** sample MCUs (e.g. [zx16](https://github.com/shalan/zx16)) consume this IP; they are not in this repo.

## Layout

```
rtl/           # zxip_top + cache, fill FSM, PHY, AHB/APB
tb/            # SST26 + unmapped co-sim
synth/         # Yosys + sky130 scripts
sta/           # OpenSTA constraints / runners
sky130/        # Liberty for map/STA
specs.md       # Architecture & CSR map
RTL_PLAN.md    # Implementation notes
docs/          # Deferred features
```

Top module: **`zxip_top`**.

## Quick sim (SST26 model)

Requires `iverilog` and `vvp`.

```bash
./tb/scripts/run_sst26_iverilog.sh          # 16-bit host, 16×16 cache
LINES=8 BYTES=16 ./tb/scripts/run_sst26_iverilog.sh
./tb/scripts/run_ahb32_iverilog.sh          # 32-bit host smoke (RV32-style)
```

16-bit suite: SPI baseline, SPI↔QSPI, continuous mode, bit-bang program, AHB write ERROR, prefetch.  
32-bit suite: word/half reads, SPI+QSPI, unaligned-word ERROR.

## Documentation

| Doc | Content |
|-----|---------|
| [`specs.md`](specs.md) | Architecture, memory map, CSR fields |
| [`RTL_PLAN.md`](RTL_PLAN.md) | Phases and structure |
| [`docs/DEFERRED.md`](docs/DEFERRED.md) | S28HS co-sim depth, DTR, etc. |

### CTRL register (APB offset `0x00`)

| Bit | Name |
|-----|------|
| 0 | `XIP_EN` |
| 1 | `BB_EN` |
| 2 | `CACHE_INV` (W1P) |
| 3 | `CONT_EN` |
| 4 | `EXIT_CONT` (W1P) |
| 5 | `SOFT_RST` (W1P) |
| 6 | `XIP_MODE` (0=SPI, 1=QSPI) |
| 7 | `DTR_EN` (stub) |
| 8 | `MODE_PHASE_EN` |
| 10:9 | `SPI_CMD` |
| 11 | `PREFETCH_EN` |

## Synthesis / STA (optional)

```bash
yosys -l synth/synth_sky130.log -s synth/synth_sky130.ys
# STA: see sta/run_opensta_docker.sh
```

## Author

Mohamed Shalan \<mshalan@aucegypt.edu\>

## License

Apache License 2.0 — see [LICENSE](LICENSE).
