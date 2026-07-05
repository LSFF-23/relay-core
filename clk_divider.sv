module clk_divider 
import relay_pkg::*;
#(
    parameter int LIMIT = DIVIDER_FACTOR
)
(
    clk,
    rstn,
    sample_en
);

localparam LIMIT_SIZE = $clog2(LIMIT);

input logic clk;
input logic rstn;
output logic sample_en;

logic [LIMIT_SIZE-1:0] counter;

always_ff @(posedge clk)
    if (!rstn) begin
        sample_en <= '0;
        counter <= '0;
    end else
        if (counter == LIMIT - 1) begin
            sample_en <= 1'b1;
            counter <= '0;
        end else begin
            sample_en <= 1'b0;
            counter <= counter + 1'b1;
        end

endmodule