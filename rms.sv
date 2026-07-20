module rms (
    clk,
    rst_n,
    sample_en,
    sample,
    out,
    valid
);

import relay_pkg::*;

input logic clk;
input logic rst_n;
input logic sample_en;
input logic signed [ADC_DW-1:0] sample;
output logic [ACC_DW-1:0] out;
output logic valid;

localparam int ALPHA_SHIFT = 8;
localparam int SQ_DW = 2 * ADC_DW;
localparam int SUM_DW = SQ_DW + INDEX_SIZE;

reg signed [2*ADC_DW-1:0] dc_acc;
wire signed [2*ADC_DW-1:0] sample_ext = {sample, ADC_DW'(0)};
wire signed [ADC_DW-1:0] dc_offset = dc_acc[2*ADC_DW-1:ADC_DW];
wire signed [ADC_DW-1:0] ac_signal = sample - dc_offset;

wire [SQ_DW-1:0] sq_in = $unsigned((2*ADC_DW)'(ac_signal) * (2*ADC_DW)'(ac_signal));

logic [SQ_DW-1:0] sq_buffer [0:BUFFER_SIZE-1];
logic [INDEX_SIZE-1:0] buf_ptr;
logic [SUM_DW-1:0] sum_sq;

wire [SUM_DW-1:0] sum_next = sum_sq - sq_buffer[buf_ptr] + sq_in;
wire [SQ_DW-1:0] mean_2t = SQ_DW'(sum_next >> (INDEX_SIZE - 1));

logic start_sqrt;
logic [SQ_DW-1:0] sqrt_in;
logic [ADC_DW-1:0] q_out;
logic sqrt_valid;

nnr_sqrt #(
    .IN_SIZE(SQ_DW)
) u_nnr_sqrt (
    .clk(clk),
    .rstn(rst_n),
    .sample_en(start_sqrt),
    .D_in(sqrt_in),
    .Q_out(q_out),
    .valid(sqrt_valid)
);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        dc_acc <= '0;
        buf_ptr <= '0;
        sum_sq <= '0;
        start_sqrt <= 1'b0;
        sqrt_in <= '0;
        out <= '0;
        valid <= 1'b0;
        for (int i = 0; i < BUFFER_SIZE; i = i + 1) sq_buffer[i] <= '0;
    end else begin
        if (sqrt_valid) begin
            out <= q_out << (INDEX_SIZE - 1);
            valid <= 1'b1;
        end else if (sample_en) begin
            dc_acc <= dc_acc + ((sample_ext - dc_acc) >>> ALPHA_SHIFT);
            sum_sq <= sum_next;
            sq_buffer[buf_ptr] <= sq_in;
            buf_ptr <= (buf_ptr == BUFFER_SIZE - 1) ? '0 : buf_ptr + 1'b1;
            sqrt_in <= mean_2t;
            start_sqrt <= 1'b1;
        end else begin
            start_sqrt <= 1'b0;
            valid <= 1'b0;
        end
    end
end

endmodule