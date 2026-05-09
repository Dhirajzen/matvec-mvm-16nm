// ============================================================
// Matrix-Vector Multiplier: y = W * x
//   W  : N×N weight matrix, W_W-bit signed elements (row-major packed)
//   x  : N-element input vector, IN_W-bit signed elements (packed)
//   y  : N-element output vector, ACC_W-bit signed elements (packed)
//
// Target process : TSMC 16nm FinFET (16FF+), SVT standard-cell library
// EDA flow       : Synopsys Design Compiler (compile_ultra -retime)
//
// For N=32, IN_W=2, W_W=8:
//   PROD_W = 10, LEVELS = 5, ACC_W = 15
//   Critical path: ~34 FO4 x 11 ps = ~374 ps logic
//                  ~560 ps post-routing (1.5x derating) -> F_max ~1.6 GHz
//   VDD nominal  : 0.8 V  (SVT); 0.72 V (LVT low-power corner)
// ============================================================
`timescale 1ns / 1ps

module matvec_mul #(
    parameter  integer N      = 32,          // matrix/vector dimension
    parameter  integer IN_W   = 2,           // input element width (signed)
    parameter  integer W_W    = 8,           // weight element width (signed)
    // Derived (do not override)
    localparam integer PROD_W = IN_W + W_W,  // exact product width = 10
    localparam integer LEVELS = $clog2(N),   // adder tree depth   = 5
    localparam integer ACC_W  = PROD_W + LEVELS  // accumulator width  = 15
)(
    // All buses are LSB = element 0
    input  wire [N*IN_W-1:0]    vec_in,   // packed input vector
    input  wire [N*N*W_W-1:0]  weights,  // packed weight matrix, row-major
    output wire [N*ACC_W-1:0]  vec_out   // packed output vector
);

    genvar i, j;

    generate
        for (i = 0; i < N; i = i + 1) begin : g_row

            // ── Stage 1: Signed Multiply ────────────────────────────────
            // Both operands are sign-extended to PROD_W bits before the
            // multiply so the full signed product is captured exactly.
            // For IN_W=2 the synthesis tool reduces each "multiplier" to a
            // small MUX/negate network (no full Wallace tree needed).
            wire signed [PROD_W-1:0] prod [0:N-1];

            for (j = 0; j < N; j = j + 1) begin : g_mul
                wire signed [PROD_W-1:0] sxt_in, sxt_w;

                assign sxt_in = {{(PROD_W-IN_W){vec_in[(j+1)*IN_W-1]}},
                                   vec_in[j*IN_W +: IN_W]};

                assign sxt_w  = {{(PROD_W-W_W){weights[(i*N+j+1)*W_W-1]}},
                                   weights[(i*N+j)*W_W +: W_W]};

                assign prod[j] = sxt_in * sxt_w;
            end

            // ── Stage 2: Sign-extend products to accumulator width ──────
            wire signed [ACC_W-1:0] lv0 [0:N-1];

            for (j = 0; j < N; j = j + 1) begin : g_ext
                assign lv0[j] = {{(ACC_W-PROD_W){prod[j][PROD_W-1]}}, prod[j]};
            end

            // ── Stage 3: Binary Adder Tree (5 levels for N=32) ─────────
            // Each level halves the operand count.
            // All intermediate wires keep ACC_W bits; the summation range
            // [-8192, 8192] is always representable in 15-bit signed.
            wire signed [ACC_W-1:0] lv1 [0:N/2 -1];
            wire signed [ACC_W-1:0] lv2 [0:N/4 -1];
            wire signed [ACC_W-1:0] lv3 [0:N/8 -1];
            wire signed [ACC_W-1:0] lv4 [0:N/16-1];
            wire signed [ACC_W-1:0] lv5;

            for (j = 0; j < N/2;  j = j+1) begin : g_l1
                assign lv1[j] = lv0[2*j] + lv0[2*j+1];
            end
            for (j = 0; j < N/4;  j = j+1) begin : g_l2
                assign lv2[j] = lv1[2*j] + lv1[2*j+1];
            end
            for (j = 0; j < N/8;  j = j+1) begin : g_l3
                assign lv3[j] = lv2[2*j] + lv2[2*j+1];
            end
            for (j = 0; j < N/16; j = j+1) begin : g_l4
                assign lv4[j] = lv3[2*j] + lv3[2*j+1];
            end

            assign lv5 = lv4[0] + lv4[1];

            // ── Output slice ────────────────────────────────────────────
            assign vec_out[i*ACC_W +: ACC_W] = lv5;

        end
    endgenerate

endmodule
