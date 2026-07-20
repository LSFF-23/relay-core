module peak_detector (
    clk,
    rst_n,
    sample_en,
    sample,
    out,
    valid
);

import relay_pkg::*;

localparam int ALPHA_SHIFT = 8;

input logic clk;
input logic rst_n;
input logic sample_en;
input logic signed [ADC_DW-1:0] sample;
output logic [ACC_DW-1:0] out;
output logic valid;

logic signed [2*ADC_DW-1:0] dc_acc;
wire signed [2*ADC_DW-1:0] sample_ext = {sample, ADC_DW'(0)};
wire signed [ADC_DW-1:0] dc_offset = dc_acc[2*ADC_DW-1:ADC_DW];
wire signed [ADC_DW-1:0] ac_signal = sample - dc_offset;
wire [ADC_DW-1:0] abs_ac = (ac_signal < 0) ? -ac_signal : ac_signal;

logic [ADC_DW-1:0] ring_buffer [0:BUFFER_SIZE-1];
logic [INDEX_SIZE-1:0] buf_ptr;
logic buffer_full;

logic [ADC_DW-1:0] running_peak;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        dc_acc <= '0;
        buf_ptr <= '0;
        buffer_full <= 1'b0;
        running_peak <= '0;
        out <= '0;
        valid <= 1'b0;
        for (int i = 0; i < BUFFER_SIZE; i++) begin
            ring_buffer[i] <= '0;
        end
    end else begin
        valid <= 1'b0;

        if (sample_en) begin
            dc_acc <= dc_acc + ((sample_ext - dc_acc) >>> ALPHA_SHIFT);

            ring_buffer[buf_ptr] <= abs_ac;

            if (buf_ptr == BUFFER_SIZE - 1) begin
                buf_ptr <= '0;
                buffer_full <= 1'b1;
            end else begin
                buf_ptr <= buf_ptr + 1'b1;
            end

            if (abs_ac > running_peak) begin
                running_peak <= abs_ac;
            end else if (ring_buffer[buf_ptr] == running_peak) begin
                running_peak <= abs_ac;
            end

            if (buffer_full || (buf_ptr == BUFFER_SIZE - 1)) begin
                out <= ACC_DW'(running_peak) << (INDEX_SIZE - 1);
                valid <= 1'b1;
            end
        end
    end
end

endmodule