// ansi 27 - undervoltage relay
module ansi27 (
    clk,
    rst_n,
    sample_en,
    v_in,
    v_threshold,
    hysteresis,
    sample_limit,
    trip
);

import relay_pkg::*;

input logic clk;
input logic rst_n;
input logic sample_en;
input logic [ACC_DW-1:0] v_in;
input logic [ACC_DW-1:0] v_threshold;
input logic [ACC_DW-1:0] hysteresis;
input logic [15:0] sample_limit;
output logic trip;

logic [15:0] threshold_counter;
logic undervoltage;

wire [ACC_DW-1:0] upper_limit = v_threshold;
wire [ACC_DW-1:0] lower_limit = v_threshold - hysteresis;

wire below_upper = v_in < upper_limit;
wire below_lower = v_in < lower_limit;
wire counter_limit = threshold_counter >= sample_limit;

always_ff @(posedge clk)
    if (!rst_n) begin
        threshold_counter <= '0;
        undervoltage <= '0;
    end else if (sample_en) begin
        if (below_upper) begin
            if (!counter_limit && (undervoltage || below_lower)) threshold_counter <= threshold_counter + 1'b1;
            if (below_lower) undervoltage <= 1'b1;
        end else begin
            undervoltage <= 1'b0;
            threshold_counter <= '0;
        end
    end

assign trip = undervoltage && counter_limit;

endmodule