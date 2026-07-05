module relay_avs (
    clk,
    clk_hps,
    rst_n,
    trip,
    avs_address,
    avs_read,
    avs_readdata,
    avs_write,
    avs_writedata
);

// REMINDER: REGISTERED READING (READ LATENCY = 1)

import relay_pkg::*;

input logic clk;
input logic clk_hps;
input logic rst_n;
output logic trip;
// Avalon-MM Slave Interface
input logic [2:0] avs_address;
input logic avs_read;
output logic [31:0] avs_readdata;
input logic avs_write;
input logic [31:0] avs_writedata;

// fifo interface simulating adc: depth = 1024
logic aclr;
logic [ADC_DW-1:0] data;
logic rdclk;
logic rdreq;
logic wrclk;
logic wrreq;
logic [ADC_DW-1:0] adc_out;
logic rdempty;
logic [FIFO_INDEX-1:0] wrusedw;

logic [ACC_DW-1:0] a59_pickup;
logic [ACC_DW-1:0] a59_hysteresis;
logic [15:0] a59_limit;

logic [ADC_DW-1:0] adc_vin;
logic sample_en, sdft_valid;
logic [ACC_DW-1:0] sdft_out;

assign aclr = !rst_n;
assign rdreq = sample_en && !rdempty;
assign wrreq = avs_write && avs_address == 3'b100;
fifo_ip u_fifo_ip (
    .aclr(aclr),
    .data(avs_writedata[ADC_DW-1:0]),
    .rdclk(clk),
    .rdreq(rdreq),
    .wrclk(clk_hps),
    .wrreq(wrreq),
    .q(adc_vin),
    .rdempty(rdempty),
    .wrusedw(wrusedw)
);

clk_divider u_clk_divider (
    .clk(clk),
    .rstn(rst_n),
    .sample_en(sample_en)
);

sdft u_sdft (
    .clk(clk),
    .rstn(rst_n),
    .sample_en(rdreq),
    .sample(adc_vin),
    .out(sdft_out),
    .valid(sdft_valid)
);

ansi59 u_ansi59 (
    .clk(clk),
    .rstn(rst_n),
    .sample_en(sdft_valid),
    .v_in(sdft_out),
    .v_pickup(a59_pickup),
    .hysteresis(a59_hysteresis),
    .sample_limit(a59_limit),
    .trip(trip)
);

always_ff @(posedge clk_hps)
    if (!rst_n) begin
        a59_pickup <= '0;
        a59_hysteresis <= '0;
        a59_limit <= '0;
    end else if (avs_write) begin
        case (avs_address)
            3'b001: a59_pickup <= avs_writedata[ACC_DW-1:0];
            3'b010: a59_hysteresis <= avs_writedata[ACC_DW-1:0];
            3'b011: a59_limit <= avs_writedata[15:0];
        endcase
    end

always_ff @(posedge clk_hps)
    if (!rst_n)
        avs_readdata <= '0;
    else if (avs_read)
        case (avs_address)
            3'b000: avs_readdata <= 32'(wrusedw);
            3'b001: avs_readdata <= 32'(a59_pickup);
            3'b010: avs_readdata <= 32'(a59_hysteresis);
            3'b011: avs_readdata <= 32'(a59_limit);
            default: avs_readdata <= '0;
        endcase
    else
        avs_readdata <= '0;

endmodule