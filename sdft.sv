// sliding dft, clean formula + original references at https://www.comm.utoronto.ca/~dimitris/ece431/slidingdft.pdf
// pipelined operations to keep fmax high
module sdft (
    clk,
    rstn,
    sample_en,
    sample,
    out,
    valid
);

import relay_pkg::*;

input logic clk;
input logic rstn;
input logic sample_en;
input logic [ADC_DW-1:0] sample;
output logic [ACC_DW-1:0] out;
output logic valid;

logic signed [ADC_DW-1:0] COS_TABLE [BUFFER_SIZE];
logic signed [ADC_DW-1:0] SIN_TABLE [BUFFER_SIZE];
initial begin
    $readmemh(COS_PATH, COS_TABLE);
    $readmemh(SIN_PATH, SIN_TABLE);
end

logic signed [ADC_DW-1:0] buffer [BUFFER_SIZE] = '{default: '0};
logic [INDEX_SIZE-1:0] index;
logic signed [ADC_DW-1:0] cur_sample, old_sample;
logic signed [ADC_DW-1:0] cos_reg, sin_reg;
logic signed [ADC_DW:0] delta_reg;
logic signed [ACC_DW-1:0] re_acc, im_acc;
logic signed [ACC_DW+ADC_DW-1:0] re_cos, im_sin, reshift_reg, imshift_reg;
logic signed [MAG_DW-1:0] re2, im2;

enum logic [3:0] {
    SDFT_IDLE,
    SDFT_DELTA,
    SDFT_TRIG,
    SDFT_SHIFT,
    SDFT_UPDATE,
    SDFT_SQUARE,
    SDFT_SQRT,
    SDFT_MAGNITUDE,
    SDFT_DONE
} state, next_state;

wire sqrt_en = state == SDFT_SQRT;
wire signed [MAG_DW-1:0] mag2 = re2 + im2;
wire [ACC_DW-1:0] Q_out;
wire sqrt_valid;
nnr_sqrt #(.IN_SIZE(MAG_DW)) u_nnr_sqrt (
    .clk(clk),
    .rstn(rstn),
    .sample_en(sqrt_en),
    .D_in(mag2),
    .Q_out(Q_out),
    .valid(sqrt_valid)
);

always_ff @(posedge clk)
    if (!rstn)
        state <= SDFT_IDLE;
    else
        state <= next_state;

always_comb begin
    next_state = state;
    case (state)
        SDFT_IDLE: if (sample_en) next_state = SDFT_DELTA;
        SDFT_DELTA: next_state = SDFT_TRIG;
        SDFT_TRIG: next_state = SDFT_SHIFT;
        SDFT_SHIFT: next_state = SDFT_UPDATE;
        SDFT_UPDATE: next_state = SDFT_SQUARE;
        SDFT_SQUARE: next_state = SDFT_SQRT;
        SDFT_SQRT: next_state = SDFT_MAGNITUDE;
        SDFT_MAGNITUDE: if (sqrt_valid) next_state = SDFT_DONE;
        SDFT_DONE: next_state = SDFT_IDLE;
        default: next_state = SDFT_IDLE;
    endcase
end

wire signed [ADC_DW-1:0] sample_offset = $signed(sample) - $signed(ADC_DW'(ADC_OFFSET));

wire signed [ADC_DW:0] delta_comb = cur_sample - old_sample;

wire signed [ACC_DW+ADC_DW-1:0] delta_cos = delta_reg * cos_reg;
wire signed [ACC_DW+ADC_DW-1:0] delta_sin = delta_reg * sin_reg;

wire signed [ACC_DW+ADC_DW-1:0] round_const = $signed((ACC_DW + ADC_DW)'(1) << (ADC_DW - 2));
wire signed [ACC_DW+ADC_DW-1:0] re_shift = (re_cos + round_const) >>> (ADC_DW - 1);
wire signed [ACC_DW+ADC_DW-1:0] im_shift = (im_sin + round_const) >>> (ADC_DW - 1);

wire signed [ACC_DW-1:0] reacc_new = re_acc + $signed(reshift_reg[ACC_DW-1:0]);
wire signed [ACC_DW-1:0] imacc_new = im_acc + $signed(imshift_reg[ACC_DW-1:0]);

wire signed [MAG_DW-1:0] re_sqr = re_acc * re_acc;
wire signed [MAG_DW-1:0] im_sqr = im_acc * im_acc;

wire [INDEX_SIZE-1:0] new_index = (index == INDEX_SIZE'(BUFFER_SIZE - 1)) ? INDEX_SIZE'(0) : index + 1'b1;

always_ff @(posedge clk)
    if (!rstn) begin
        index <= '0;
        cur_sample <= '0;
        old_sample <= '0;
        cos_reg <= '0;
        sin_reg <= '0;
        delta_reg <= '0;
        re_acc <= '0;
        im_acc <= '0;
        re_cos <= '0;
        im_sin <= '0;
        reshift_reg <= '0;
        imshift_reg <= '0;
        re2 <= '0;
        im2 <= '0;
        out <= '0;
        valid <= 0;
        for (int i = 0; i < BUFFER_SIZE; i++) buffer[i] <= '0;
    end else begin
        case (state)
            SDFT_IDLE: begin
                valid <= 1'b0;
                if (sample_en) begin
                    cur_sample <= sample_offset;
                    old_sample <= buffer[index];
                end
            end
            SDFT_DELTA: begin
                cos_reg <= COS_TABLE[index];
                sin_reg <= SIN_TABLE[index];
                delta_reg <= delta_comb;
            end
            SDFT_TRIG: begin
                re_cos <= delta_cos;
                im_sin <= delta_sin;
            end
            SDFT_SHIFT: begin
                reshift_reg <= re_shift;
                imshift_reg <= im_shift;
            end
            SDFT_UPDATE: begin
                re_acc <= reacc_new;
                im_acc <= imacc_new;
            end
            SDFT_SQUARE: begin
                re2 <= re_sqr;
                im2 <= im_sqr;
            end
            SDFT_DONE: begin
                buffer[index] <= cur_sample;
                index <= new_index;
                out <= Q_out;
                valid <= 1'b1;
            end
        endcase
    end

endmodule