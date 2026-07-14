# ZXip

**ZXip** is a small **execute-in-place (XiP) QSPI flash controller** for AHB-Lite SoCs.

It targets instruction and RO-data fetch from SPI/QSPI NOR flash with a line cache,
optional next-line prefetch, continuous mode, and an APB CSR + bit-bang path for
device bring-up (e.g. program, status, mode switch).

| | |
|--|--|
| Host bus (v1) | **16-bit AHB-Lite** RO slave + **16-bit APB** CSRs |
| Flash | SPI 1-1-1 (`0x0B` / `0x03`) and QSPI 1-4-4 (`0xEB`) |
| Cache | Parameterized lines × bytes (8/16 × 8/16), default 16×16 B |
| RTL | IEEE Verilog-2005 |
| License | Apache-2.0 |

**Roadmap:** parameterized **32-bit AHB** host port for RV32 integration.  
**SoC integration:** ZX16 sample SoC lives in the [zx16](https://github.com/shalan/zx16) tree (consumer of this IP), not in this repo.

## Layout

```
rtl/           # zxip_top + cache, fill FSM, PHY, AHB/APB
tb/            # SST26 / unmapped / S28HS co-sim
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
./tb/scripts/run_sst26_iverilog.sh          # default 16×16 cache
./tb/scripts/run_sst26_iverilog.sh 8 16     # 8 lines × 16 B
```

Covers SPI baseline, SPI↔QSPI, continuous mode, bit-bang program, AHB write ERROR, prefetch.

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
