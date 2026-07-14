// SPDX-License-Identifier: Apache-2.0
// XiP shared constants (macros for portable `include)
//
// Cache geometry is compile-time selectable (override with +define+ / -D):
//   XIP_CACHE_LINES  : 8 or 16  (default 16)
//   XIP_LINE_BYTES   : 8 or 16  (default 16)
// Capacity = LINES * LINE_BYTES  →  64 / 128 / 128 / 256 B
//
`ifndef XIP_PKG_PARAMS_VH
`define XIP_PKG_PARAMS_VH

`ifndef XIP_CACHE_LINES
`define XIP_CACHE_LINES 16
`endif

`ifndef XIP_LINE_BYTES
`define XIP_LINE_BYTES  16
`endif

// Sanity: only 8/16 supported for both knobs
`ifndef XIP_LINE_BITS
`define XIP_LINE_BITS   (`XIP_LINE_BYTES * 8)
`endif

// Max fill bus width (always 128; lower LINE_BITS used when LINE_BYTES=8)
`define XIP_FILL_BUS_W  128

`define XIP_PHYS_W      20
`define XIP_SPI_AW      24

`define XIP_CMD_READ      8'h03
`define XIP_CMD_FAST_READ 8'h0B
`define XIP_CMD_QIO_SDR   8'hEB
`define XIP_CMD_QIO_DTR   8'hED
`define XIP_DUMMY_DEFAULT 6'd8

`define XIP_REG_CTRL      8'h00
`define XIP_REG_STATUS    8'h02
`define XIP_REG_CLKDIV    8'h04
`define XIP_REG_DUMMY     8'h06
`define XIP_REG_MODE_STAY 8'h08
`define XIP_REG_MODE_EXIT 8'h0A
`define XIP_REG_FIXED_PG  8'h0C
`define XIP_REG_QSPI_CMD  8'h0E
`define XIP_REG_BB_CTRL   8'h10
`define XIP_REG_BB_IO     8'h12
`define XIP_REG_DTR_PHY   8'h14

`endif
