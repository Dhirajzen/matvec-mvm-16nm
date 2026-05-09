# Synthesizable Matrix-Vector Multiplier — TSMC 16 nm

**Course:** Advanced Projects — ECE-GY 9953  
**Student:** Dhirajzen Bagawath Geetha Kumaravel (db5309)  
**Institution:** NYU Tandon School of Engineering  
**Target PDK:** TSMC 16 nm FinFET

---

## Overview

Fully synthesizable, combinational 32×32 signed matrix-vector multiplier (MVM)
targeting the TSMC 16 nm standard-cell ASIC flow (Synopsys Design Compiler).

**Operation:** `y = W · x`

| Signal | Dimension | Width | Type |
|--------|-----------|-------|------|
| `vec_in` | 32 elements | 2-bit signed | Input activations {−2,−1,0,+1} |
| `weights` | 32×32 elements | 8-bit signed | INT8 weight matrix (row-major) |
| `vec_out` | 32 elements | 15-bit signed | Output accumulation |

---

## Key Design Points

- **No Wallace tree** — 2-bit inputs degenerate each multiplier to a 4-way
  decode-and-negate network (~20–30 NAND2-eq per cell, 3–5× area saving)
- **5-level binary adder tree** — log₂(32) = 5 levels; 31 adders × 15 bits
  = 465 FA cells per row, 14,880 FA cells total
- **No overflow** — bit widths derived analytically: PROD_W = 10, ACC_W = 15

---

## Timing Summary (TSMC 16 nm, SVT, TT/0.8 V/25 °C)

| Metric | Value |
|--------|-------|
| FO4 unit delay | 11 ps |
| Critical path (gate-level) | ~374 ps (34 FO4) |
| Critical path (post-route, 1.5× derate) | ~561 ps |
| Practical F_max | **1.5 – 1.8 GHz** |
| Pipelined F_max (mid-tree register) | **> 3 GHz** |

---

## Repository Contents

```
matvec_project/
├── matvec_mul.v        # Synthesizable RTL (SystemVerilog)
├── generate_report.py  # Python script to regenerate the PDF report
├── MatVec_MUL_Report.pdf  # Final project report
└── README.md
```

---

## Regenerating the Report

```bash
pip install reportlab
python3 generate_report.py
```

## Synthesis (Synopsys DC)

```tcl
read_verilog matvec_mul.v
elaborate matvec_mul
set_max_delay 560 -from [all_inputs] -to [all_outputs]
set_max_fanout 8 [all_inputs]
set_max_transition 120 [all_inputs]
compile_ultra -retime
report_timing
```
