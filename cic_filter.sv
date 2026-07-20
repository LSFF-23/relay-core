/* 
    CIC filter I asked AI to create since altera one is limited for 1 hour and I want quartus to stfu
*/
// `default_nettype none

module cic_filter #(
    parameter int IN_DW  = 12,       // Largura de bits da entrada (ex: ADC 12 bits)
    parameter int OUT_DW = 12,       // Largura de bits da saída
    parameter int N      = 3,        // Número de estágios (Integrador/Comb)
    parameter int R      = 130,      // Fator de dizimação (Decimation Rate)
    parameter int M      = 1         // Atraso do Comb (geralmente 1)
)(
    input  logic             clk,
    input  logic             reset_n,
    input  logic [IN_DW-1:0] in_data,
    input  logic             in_valid,
    output logic             in_ready,
    input  logic [1:0]       in_error,
    
    output logic [OUT_DW-1:0] out_data,
    output logic             out_valid,
    input  logic             out_ready,
    output logic [1:0]       out_error
);

    // 1. Cálculo automático do Bit Growth
    localparam int BIT_GROWTH = $clog2((R * M)**N);
    localparam int ACC_DW     = IN_DW + BIT_GROWTH;

    assign in_ready  = 1'b1;
    assign out_error = '0;

    // Sinais internos com largura expandida
    logic signed [ACC_DW-1:0] int_stage [0:N];
    logic signed [ACC_DW-1:0] comb_delay [0:N-1][0:M];
    logic signed [ACC_DW-1:0] comb_stage [0:N];

    // Controle de Dizimação
    logic [$clog2(R)-1:0] rate_cnt;
    logic dec_pulse;

    // Extensão de sinal da entrada
    assign int_stage[0] = in_data;

    // =========================================================================
    // 2. ESTÁGIOS INTEGRADORES (Roda na taxa ALTA: in_valid)
    // =========================================================================
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : g_integrators
            always_ff @(posedge clk or negedge reset_n) begin
                if (!reset_n) begin
                    int_stage[i+1] <= '0;
                end else if (in_valid) begin
                    int_stage[i+1] <= int_stage[i+1] + int_stage[i];
                end
            end
        end
    endgenerate

    // =========================================================================
    // 3. DIZIMADOR (Gera o pulso para a taxa BAIXA)
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rate_cnt  <= '0;
            dec_pulse <= 1'b0;
        end else if (in_valid) begin
            if (rate_cnt == R - 1) begin
                rate_cnt  <= '0;
                dec_pulse <= 1'b1;
            end else begin
                rate_cnt  <= rate_cnt + 1'b1;
                dec_pulse <= 1'b0;
            end
        end else begin
            dec_pulse <= 1'b0;
        end
    end

    // Amostra a saída do último integrador na taxa baixa
    assign comb_stage[0] = int_stage[N];

    // =========================================================================
    // 4. ESTÁGIOS COMB (Roda na taxa BAIXA: dec_pulse)
    // =========================================================================
    generate
        for (i = 0; i < N; i++) begin : g_combs
            always_ff @(posedge clk or negedge reset_n) begin
                if (!reset_n) begin
                    comb_delay[i][0] <= '0;
                    comb_stage[i+1]  <= '0;
                end else if (dec_pulse) begin
                    comb_delay[i][0] <= comb_stage[i];
                    comb_stage[i+1]  <= comb_stage[i] - comb_delay[i][0];
                end
            end
        end
    endgenerate

    // =========================================================================
    // 5. SAÍDA (Truncamento dos bits extras para casar com OUT_DW)
    // =========================================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            out_data  <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= dec_pulse;
            if (dec_pulse) begin
                // Trunca os bits menos significativos dividindo pelo Ganho (BIT_GROWTH)
                out_data <= comb_stage[N][ACC_DW-1 -: OUT_DW];
            end
        end
    end
endmodule