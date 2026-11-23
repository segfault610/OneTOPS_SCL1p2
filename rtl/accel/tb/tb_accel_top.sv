// Self-checking testbench: independent behavioural model of the same xorshift-driven C = A x B stream.
`timescale 1ns/1ps
module tb_accel_top;
    localparam int N = 2, L = 32, OFS = 2;
    localparam logic [31:0] SEED = 32'hC0FFEE01;
    logic clk = 0, rst_n = 0, start = 0; wire busy, done, pass; wire [7:0] sb; wire [15:0] rc;
    logic [1:0] sel = 0;
    logic [31:0] gold;
    accel_top #(.N(N), .STREAM_LEN(L), .SEED(SEED)) dut_g (.clk(clk), .rst_n(rst_n), .start(start), .busy(busy),
        .done(done), .pass(pass), .sig_sel(sel), .sig_byte(sb), .run_count(rc));
    always #5 clk = ~clk;

    function automatic logic [31:0] xs(input logic [31:0] x);
        logic [31:0] a, b; a = x ^ (x << 13); b = a ^ (a >> 17); return b ^ (b << 5);
    endfunction

    // reference: B[i][j] = byte i of xs^(j)(SEED)... column j loaded at LOAD cycle j (rnd advanced j times)
    function automatic logic [31:0] model();
        logic [31:0] r; int B [N][N]; int A [L][N]; logic [31:0] s; int c;
        r = SEED;
        for (int j = 0; j < N; j++) begin for (int i = 0; i < N; i++) B[i][j] = $signed(r[8*i +: 8]); r = xs(r); end
        for (int t = 0; t < L; t++) begin for (int i = 0; i < N; i++) A[t][i] = $signed(r[8*i +: 8]); r = xs(r); end
        // behavioural C = A x B; the DUT sums the N column outputs seen each cycle (skew-aligned by the array) --
        // rather than model the skew, accumulate the per-(row t) sum over columns at the cycle it appears.
        // Column j of row t appears at DUT cycle t + j + const, so each cycle k adds sum_j C[k-j-const][j].
        s = 0;
        for (int k = 0; k < L + 2*N + 3; k++) begin
            c = 0;
            for (int j = 0; j < N; j++) begin
                int t2; t2 = k - j - OFS;
                if (t2 >= 0 && t2 < L) for (int i = 0; i < N; i++) c += A[t2][i] * B[i][j];
            end
            s = {s[30:0], s[31]} ^ 32'(c);
        end
        return s;
    endfunction

    int errors = 0;
    initial begin
        gold = model();
        repeat (4) @(posedge clk); rst_n = 1;
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        wait (done); @(posedge clk);
        for (int k = 0; k < 4; k++) begin sel = k[1:0]; #1; if (sb !== gold[8*k +: 8]) begin errors++; $display("sig byte %0d: %h != %h", k, sb, gold[8*k +: 8]); end end
        $display("GOLD=%h  (put in accel_top GOLD)", gold);
        if (!pass) errors++;
        if (errors == 0) $display("PASS: signature matches the behavioural model"); else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
