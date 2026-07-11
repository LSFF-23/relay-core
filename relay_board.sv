`default_nettype none

module debouncer 
(
    clk,
    rst_n,
    in,
    out
);

import relay_pkg::*;

input logic clk;
input logic rst_n;
input logic in;
output logic out;

localparam LIMIT_SIZE = $clog2(DEBOUNCER_LIMIT);

logic [LIMIT_SIZE-1:0] counter;
logic [1:0] in_sync;
logic value;

always_ff @(posedge clk)
    if (!rst_n)
        in_sync <= '0;
    else
        in_sync <= {in_sync[0], in};

always_ff @(posedge clk)
    if (!rst_n) begin
        value <= 1'b1;
        counter <= '0;
    end else if (value != in_sync[1])
        if (counter == DEBOUNCER_LIMIT - 1) begin
            value <= in_sync[1];
            counter <= '0;
        end else
            counter <= counter + 1'b1;
    else
        counter <= '0;

assign out = value;

endmodule

module decoder7 (
    clk,
    rst_n,
    sample_en,
    bcd,
    segments
);

input logic clk;
input logic rst_n;
input logic sample_en;
input logic [3:0] bcd;
output logic [6:0] segments;

always_ff @(posedge clk)
    if (!rst_n)
        segments <= '1;
    else if (sample_en)
        case (bcd)
            4'b0000: segments <= 7'b1000000;
            4'b0001: segments <= 7'b1111001;
            4'b0010: segments <= 7'b0100100;
            4'b0011: segments <= 7'b0110000;
            4'b0100: segments <= 7'b0011001;
            4'b0101: segments <= 7'b0010010;
            4'b0110: segments <= 7'b0000010;
            4'b0111: segments <= 7'b1111000;
            4'b1000: segments <= 7'b0000000;
            4'b1001: segments <= 7'b0010000;
            4'b1010: segments <= 7'b0001000; // A
            4'b1011: segments <= 7'b1100000; // b
            4'b1100: segments <= 7'b0110001; // C
            4'b1101: segments <= 7'b1000010; // d
            4'b1110: segments <= 7'b0110000; // E
            4'b1111: segments <= 7'b0111000; // F
            default: segments <= '1;
        endcase

endmodule

module double_dabbler 
(
    clk,
    rst_n,
    sample_en,
    in,
    out,
    valid
);

input logic clk;
input logic rst_n;
input logic sample_en;
input logic [11:0] in;
output logic [15:0] out;
output logic valid;

logic [11:0] cur_in;
logic [15:0] cur_out, shifted_out;
logic [3:0] counter;
logic [13:0] valid_bus;

wire [11:0] shifted_in = cur_in << 1;
assign shifted_out[15:12] = (cur_out[15:12] > 4) ? cur_out[15:12] + 2'b11 : cur_out[15:12];
assign shifted_out[11:8] = (cur_out[11:8] > 4) ? cur_out[11:8] + 2'b11 : cur_out[11:8];
assign shifted_out[7:4] = (cur_out[7:4] > 4) ? cur_out[7:4] + 2'b11 : cur_out[7:4];
assign shifted_out[3:0] = (cur_out[3:0] > 4) ? cur_out[3:0] + 2'b11 : cur_out[3:0];
always_ff @(posedge clk)
    if (!rst_n) begin
        cur_in <= '0;
        cur_out <= '0;
        counter <= '0;
    end else if (sample_en) begin
        cur_in <= in;
        cur_out <= '0;
        counter <= 4'd12;
    end else if (counter != 0) begin
        cur_in <= shifted_in;
        cur_out <= {shifted_out[14:0], cur_in[11]};
        counter <= counter - 1'b1;
    end

always_ff @(posedge clk)
    if (!rst_n)
        valid_bus <= '0;
    else
        valid_bus <= {valid_bus[12:0], sample_en};

assign out = cur_out;
assign valid = valid_bus[13];

endmodule

module display (
    clk,
    rst_n,
    value,
    digit0,
    digit1,
    digit2,
    digit3
);

import relay_pkg::*;

input logic clk;
input logic rst_n;
input logic [11:0] value;
output logic [6:0] digit0;
output logic [6:0] digit1;
output logic [6:0] digit2;
output logic [6:0] digit3;

logic sample_en;
logic [15:0] bcd;
logic dd_valid;

clk_divider #(.LIMIT(DEBOUNCER_LIMIT)) u_clk_divider (
    .clk(clk),
    .rstn(rst_n),
    .sample_en(sample_en)
);

double_dabbler u_double_dabbler (
    .clk(clk),
    .rst_n(rst_n),
    .sample_en(sample_en),
    .in(value),
    .out(bcd),
    .valid(dd_valid)
);

decoder7 u_decoder7_d1 (
    .clk(clk),
    .rst_n(rst_n),
    .sample_en(dd_valid),
    .bcd(bcd[3:0]),
    .segments(digit0)
);

decoder7 u_decoder7_d2 (
    .clk(clk),
    .rst_n(rst_n),
    .sample_en(dd_valid),
    .bcd(bcd[7:4]),
    .segments(digit1)
);

decoder7 u_decoder7_d3 (
    .clk(clk),
    .rst_n(rst_n),
    .sample_en(dd_valid),
    .bcd(bcd[11:8]),
    .segments(digit2)
);

decoder7 u_decoder7_d4 (
    .clk(clk),
    .rst_n(rst_n),
    .sample_en(dd_valid),
    .bcd(bcd[15:12]),
    .segments(digit3)
);

endmodule


module relay_board (
    clk,
    reset_n,
    clear_fault,
    display_sel,
    display_inc,
    display_dec,
    trip_led,
    digit0,
    digit1,
    digit2,
    digit3,
    adc_convst,
    adc_dout,
    adc_din,
    adc_sclk
);

import relay_pkg::*;

localparam int A59L_SCALER = int'(A59_INTERVAL / 0.1);
localparam int A59L_STEP = int'(SAMPLING_F * 0.1);
localparam int A27L_SCALER = int'(A27_INTERVAL / 0.1);
localparam int A27L_STEP = int'(SAMPLING_F * 0.1);

input logic clk;
input logic reset_n; // btn
input logic clear_fault; // btn
input logic [2:0] display_sel; // sw
input logic display_inc; // btn
input logic display_dec; // btn
output logic trip_led;
// 7 segments = sign d4 d3 d2 d1
output logic [6:0] digit0;
output logic [6:0] digit1;
output logic [6:0] digit2;
output logic [6:0] digit3; 
// adc interface (pg. 43, de10 manual)
output logic adc_convst;
input  logic adc_dout;
output logic adc_din;
output logic adc_sclk;

logic btn_inc, btn_dec, clear_led;
logic inc_reg, dec_reg;
logic [1:0] sel_sync, sel_reg;

logic rst_sync, rst_n;
logic sample_en;
logic [INDEX_SIZE-1:0] index;

logic [ACC_DW-1:0] a59_pickup, a27_threshold;
logic [ACC_DW-1:0] a59_hysteresis, a27_hysteresis;
logic [15:0] a59_limit, a27_limit;
logic a59_trip, a27_trip;

logic [11:0] display_v;
logic [7:0] a59_timer, a27_timer;

debouncer u_debouncer_clear (
    .clk(clk),
    .rst_n(rst_n),
    .in(clear_fault),
    .out(clear_led)
);

debouncer u_debouncer_inc (
    .clk(clk),
    .rst_n(rst_n),
    .in(display_inc),
    .out(btn_inc)
);

debouncer u_debouncer_dec (
    .clk(clk),
    .rst_n(rst_n),
    .in(display_dec),
    .out(btn_dec)
);

clk_divider u_clk_divider (
    .clk(clk),
    .rstn(rst_n),
    .sample_en(sample_en)
);

/*
default altera module is generating a latch
use grep or search for "counter <=" in "altera_up_avalon_adv_adc.v"
on "if (reset)", set "counter <= 8'b0;", there are two instances of this
delete db/incremental_db folder in quartus project
replace global module (can be accessed directly from ip catalog)
generate module again using adc_controler.qsys
*/
wire adc_rst = ~rst_n;
wire [11:0] adc_ch0;
adc_controller u_adc_controller (
    .CLOCK(clk),
    .RESET(adc_rst),
    .CH0(adc_ch0),
    .CH1(),
    .CH2(),
    .CH3(),
    .CH4(),
    .CH5(),
    .CH6(),
    .CH7(),
    .ADC_CS_N(adc_convst),
    .ADC_DOUT(adc_dout),
    .ADC_DIN (adc_din),
    .ADC_SCLK(adc_sclk)
);

wire [ACC_DW-1:0] sdft_out;
wire sdft_valid;
sdft u_sdft (
    .clk(clk),
    .rstn(rst_n),
    .sample_en(sample_en),
    .sample(ADC_DW'(adc_ch0)),
    .out(sdft_out),
    .valid(sdft_valid)
);

ansi27 u_ansi27 (
    .clk(clk),
    .rst_n(rst_n),
    .sample_en(sdft_valid),
    .v_in(sdft_out),
    .v_threshold(a27_threshold),
    .hysteresis(a27_hysteresis),
    .sample_limit(a27_limit),
    .trip(a27_trip)
);

ansi59 u_ansi59 (
    .clk(clk),
    .rst_n(rst_n),
    .sample_en(sdft_valid),
    .v_in(sdft_out),
    .v_pickup(a59_pickup),
    .hysteresis(a59_hysteresis),
    .sample_limit(a59_limit),
    .trip(a59_trip)
);

display u_display (
    .clk(clk),
    .rst_n(rst_n),
    .value(display_v),
    .digit0(digit0),
    .digit1(digit1),
    .digit2(digit2),
    .digit3(digit3)
);

always_ff @(posedge clk, negedge reset_n) begin
    if (!reset_n) begin
        rst_sync <= '0;
        rst_n <= '0;
    end else begin
        rst_sync <= 1'b1;
        rst_n <= rst_sync;
    end
end

wire inc_falling = inc_reg && !btn_inc;
wire dec_falling = dec_reg && !btn_dec;
always_ff @(posedge clk)
    if (!rst_n) begin
        inc_reg <= 1'b1;
        dec_reg <= 1'b1;
    end else begin
        inc_reg <= btn_inc;
        dec_reg <= btn_dec;
    end

always_ff @(posedge clk)
    if (!rst_n) begin
        sel_sync <= '0;
        sel_reg <= '0;
    end else begin
        sel_sync <= display_sel;
        sel_reg <= sel_sync;
    end

wire [ACC_DW-1:0] a59_amp = a59_pickup >> (INDEX_SIZE - 1);
wire [ACC_DW-1:0] a59_hyst = a59_hysteresis >> (INDEX_SIZE - 1);
wire [ACC_DW-1:0] a27_amp = a27_threshold >> (INDEX_SIZE - 1);
wire [ACC_DW-1:0] a27_hyst = a27_hysteresis >> (INDEX_SIZE - 1);
always_ff @(posedge clk)
    if (!rst_n) begin
        a59_pickup <= ACC_DW'(A59_PICKUP);
        a59_hysteresis <= ACC_DW'(A59_HYSTERESIS);
        a59_limit <= 16'(A59_TIMEOUT);
        a59_timer <= 8'(A59L_SCALER);
        a27_threshold <= ACC_DW'(A27_THRESHOLD);
        a27_hysteresis <= ACC_DW'(A27_HYSTERESIS);
        a27_limit <= 16'(A27_TIMEOUT);
        a27_timer <= 8'(A27L_SCALER);
        display_v <= '0;
    end else begin
        case (sel_reg)
            3'b000, 3'b100: begin
                display_v <= 12'(sdft_out >> (INDEX_SIZE - 1));
            end
            3'b001: begin
                display_v <= 12'(a59_timer);
                if (inc_falling && a59_timer < 'd999) begin
                    a59_timer <= a59_timer + 1'b1;
                    a59_limit <= a59_limit + 16'(A59L_STEP);
                end else if (dec_falling && a59_timer > '0) begin
                    a59_timer <= a59_timer - 1'b1;
                    a59_limit <= a59_limit - 16'(A59L_STEP);
                end
            end
            3'b010: begin
                display_v <= 12'(a59_amp);
                if (inc_falling && a59_amp < 'd999)
                    a59_pickup <= a59_pickup + ACC_DW'(32);
                else if (dec_falling && a59_amp > '0)
                    a59_pickup <= a59_pickup - ACC_DW'(32);
            end
            3'b011: begin
                display_v <= 12'(a59_hyst);
                if (inc_falling && a59_hyst < 'd999)
                    a59_hysteresis <= a59_hysteresis + ACC_DW'(32);
                else if (dec_falling && a59_hyst > '0)
                    a59_hysteresis <= a59_hysteresis - ACC_DW'(32);
            end
            3'b101: begin
                display_v <= 12'(a27_timer);
                if (inc_falling && a27_timer < 'd999) begin
                    a27_timer <= a27_timer + 1'b1;
                    a27_limit <= a27_limit + 16'(A27L_STEP);
                end else if (dec_falling && a27_timer > '0) begin
                    a27_timer <= a27_timer - 1'b1;
                    a27_limit <= a27_limit - 16'(A27L_STEP);
                end
            end
            3'b110: begin
                display_v <= 12'(a27_amp);
                if (inc_falling && a27_amp < 'd999)
                    a27_threshold <= a27_threshold + ACC_DW'(32);
                else if (dec_falling && a27_amp > '0)
                    a27_threshold <= a27_threshold - ACC_DW'(32);
            end
            3'b111: begin
                display_v <= 12'(a27_hyst);
                if (inc_falling && a27_hyst < 'd999)
                    a27_hysteresis <= a27_hysteresis + ACC_DW'(32);
                else if (dec_falling && a27_hyst > '0)
                    a27_hysteresis <= a27_hysteresis - ACC_DW'(32);
            end
        endcase
    end

wire trip_trigger = a27_trip | a59_trip;
wire clear_trigger = !clear_led;
always_ff @(posedge clk)
    if (!rst_n)
        trip_led <= 1'b0;
    else if (trip_trigger)
        trip_led <= 1'b1;
    else if (clear_trigger)
        trip_led <= 1'b0;

endmodule