// accel_top.sv - self-testing INT8 matrix-multiply accelerator wrapper (OneTOPS-SCL test load)
//
// Wraps the MIT-licensed tiny-tpu systolic array (third_party/tiny-tpu, (c) 2026 Dineth Hettiarachchi)
// with a small controller + built-in self-test: pseudo-random weights/activations (xorshift32),
// stream STREAM_LEN activation vectors, fold every cycle's south-edge column sum into a 32-bit rotate-xor signature and compare
// it with a golden value. Run it at different DVS codes / clocks to find the minimum passing VDD.
`default_nettype none

module accel_top #(
    parameter int N          = 2,
    parameter int DW         = 8,             // operand width (INT8 default; INT4 etc. to save area)
    parameter int ACC_W      = 2*DW + $clog2(N) + 1,  // exact: N products of (2^(DW-1))^2
    parameter int STREAM_LEN = 32,
    parameter logic [31:0] SEED = 32'hC0FFEE01,
    parameter logic [31:0] GOLD = 32'h8A667F12  // golden signature = tb_accel_top model
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,       // pulse (sampled on clk): run one self-test
    output logic        busy,
    output logic        done,        // sticky until next start
    output logic        pass,        // valid when done
    input  logic [1:0]  sig_sel,     // which byte of the signature to show
    output logic [7:0]  sig_byte,
    output logic [15:0] run_count    // completed runs (for throughput / activity)
);
    typedef enum logic [2:0] {S_IDLE, S_CLR, S_LOAD, S_RUN, S_DRAIN, S_DONE} st_t;
    st_t st;
    logic [7:0]  cnt;
    logic [31:0] rnd, sig;

    logic arr_rst_n, load_w;
    logic signed [DW-1:0] w_col [N];
    logic signed [DW-1:0] a_vec [N];
    logic signed [DW-1:0] a_dly [N][N];
    logic signed [DW-1:0] a_west [N];
    logic signed [ACC_W-1:0] psum_south [N];
    logic signed [DW-1:0] dbg_w [N][N], dbg_a [N][N];
    logic signed [ACC_W-1:0] dbg_p [N][N];

    wire running = (st == S_RUN);

    for (genvar i = 0; i < N; i++) begin : g_in
        assign w_col[i] = rnd[DW*(i%(32/DW)) +: DW];
        assign a_vec[i] = running ? rnd[DW*(i%(32/DW)) +: DW] : '0;
        // row i delayed by i cycles (diagonal skew); a_dly[i][0] is the 1-cycle-delayed copy
        if (i == 0) begin : g_r0
            assign a_west[i] = a_vec[i];
        end else begin : g_ri
            assign a_west[i] = a_dly[i][i-1];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < N; i++) for (int k = 0; k < N; k++) a_dly[i][k] <= '0;
        end else begin
            for (int i = 0; i < N; i++) begin
                a_dly[i][0] <= a_vec[i];
                for (int k = 1; k < N; k++) a_dly[i][k] <= a_dly[i][k-1];
            end
        end
    end

    systolic_array #(.N(N), .DATA_W(DW), .ACC_W(ACC_W)) u_array (
        .clk(clk), .rst_n(arr_rst_n), .load_weight(load_w), .weight_col(w_col),
        .act_west(a_west), .psum_south(psum_south),
        .dbg_weight(dbg_w), .dbg_act(dbg_a), .dbg_psum(dbg_p));

    assign arr_rst_n = rst_n & (st != S_CLR);
    assign load_w    = (st == S_LOAD);
    assign busy      = (st != S_IDLE) && (st != S_DONE);

    logic signed [ACC_W+2:0] colsum, ext;
    always_comb begin
        colsum = '0;
        for (int j = 0; j < N; j++) begin
            ext    = psum_south[j];   // sign-extends
            colsum = colsum + ext;
        end
    end
    wire signed [31:0] colsum32 = colsum;

    // xorshift32 step
    function automatic [31:0] xs(input [31:0] x);
        reg [31:0] a, b;
        begin
            a = x ^ (x << 13);
            b = a ^ (a >> 17);
            xs = b ^ (b << 5);
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_IDLE; cnt <= '0; rnd <= SEED; sig <= '0; done <= 1'b0; pass <= 1'b0; run_count <= '0;
        end else begin
            case (st)
                S_IDLE, S_DONE: if (start) begin
                    st <= S_CLR; rnd <= SEED; sig <= '0; cnt <= '0; done <= 1'b0; pass <= 1'b0;
                end
                S_CLR:  begin st <= S_LOAD; cnt <= '0; end
                S_LOAD: begin
                    rnd <= xs(rnd); cnt <= cnt + 1'b1;
                    if (cnt == 8'(N-1)) begin st <= S_RUN; cnt <= '0; end
                end
                S_RUN: begin
                    rnd <= xs(rnd); cnt <= cnt + 1'b1; sig <= {sig[30:0], sig[31]} ^ colsum32;
                    if (cnt == 8'(STREAM_LEN-1)) begin st <= S_DRAIN; cnt <= '0; end
                end
                S_DRAIN: begin
                    cnt <= cnt + 1'b1; sig <= {sig[30:0], sig[31]} ^ colsum32;
                    if (cnt == 8'(2*N+2)) begin st <= S_DONE; done <= 1'b1; pass <= (sig == GOLD) ; run_count <= run_count + 1'b1; end
                end
                default: st <= S_IDLE;
            endcase
        end
    end

    assign sig_byte = sig[8*sig_sel +: 8];
endmodule
`default_nettype wire
