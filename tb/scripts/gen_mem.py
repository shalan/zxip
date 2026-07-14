#!/usr/bin/env python3
"""Generate a simple s28hs256m4.mem preload (byte-addressable hex)."""
from pathlib import Path

# First 1 MiB patterned; rest 0xFF (erased-like). Model AddrRANGE is 32 MiB.
SIZE = 1 << 20
OUT = Path(__file__).resolve().parents[1] / "mem" / "s28hs256m4.mem"


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w") as f:
        f.write("// s28hs256m4 preload — low 1MiB: data[addr]=addr[7:0]^addr[15:8]^addr[19:16]\n")
        for addr in range(SIZE):
            b = (addr & 0xFF) ^ ((addr >> 8) & 0xFF) ^ ((addr >> 16) & 0xFF)
            f.write(f"{b:02X}\n")
    print(f"wrote {OUT} ({SIZE} bytes)")


if __name__ == "__main__":
    main()
