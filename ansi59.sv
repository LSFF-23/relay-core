// ansi 59 - overvoltage relay
module ansi59 (
    clk,
    rst_n,
    sample_en,
    v_in,
    v_pickup,
    hysteresis,
    sample_limit,
    trip
);

import relay_pkg::*;

input logic clk;
input logic rst_n;
input logic sample_en;
input logic [ACC_DW-1:0] v_in;
input logic [ACC_DW-1:0] v_pickup;
input logic [ACC_DW-1:0] hysteresis;
input logic [15:0] sample_limit;
output logic trip;

logic [15:0] pickup_counter;
logic pickup;

wire [ACC_DW-1:0] upper_limit = v_pickup + hysteresis;
wire [ACC_DW-1:0] lower_limit = v_pickup;

wire above_upper = v_in > upper_limit;
wire above_lower = v_in > lower_limit;
wire counter_limit = pickup_counter >= sample_limit;

always_ff @(posedge clk)
    if (!rst_n) begin
        pickup_counter <= '0;
        pickup <= '0;
    end else if (sample_en) begin
        if (above_lower) begin
            if (above_upper) pickup <= 1'b1;
            if (!counter_limit && (pickup || above_upper)) pickup_counter <= pickup_counter + 1'b1;
        end else begin
            pickup <= 1'b0;
            pickup_counter <= '0;
        end
    end

assign trip = pickup && counter_limit;

endmodule