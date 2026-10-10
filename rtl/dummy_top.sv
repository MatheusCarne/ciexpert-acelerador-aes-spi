// ==============================================================================
// Módulo Dummy com Operação XOR (128-bit)
// Demonstração da etapa AddRoundKey antes da implementação completa do AES
// ==============================================================================
`timescale 1ns/1ps

module dummy_top (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [127:0] data_in,
    input  logic [127:0] key_in,
    output logic [127:0] data_out,
    output logic         valid
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 128'h0;
            valid    <= 1'b0;
        end else if (start) begin
            // Operação XOR de 128 bits (Mapeia o AddRoundKey do AES)
            data_out <= data_in ^ key_in;
            valid    <= 1'b1;
        end else begin
            valid    <= 1'b0;
        end
    end

endmodule
