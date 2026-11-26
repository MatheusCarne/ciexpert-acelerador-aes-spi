// ============================================================================
// minisoc_memory.sv
// Memória síncrona de 32 bits compartilhada entre barramento/SPI e AES-128.
// ============================================================================
module minisoc_memory #(
    parameter int DEPTH = 1024,
    parameter int ADDR_W = $clog2(DEPTH)
) (
    input  logic              clk,
    input  logic              rst_n,

    // Porta A: Acesso via SPI / host externo (quando MEM_SEL_AES == 0)
    input  logic              ext_en,
    input  logic              ext_we,
    input  logic [ADDR_W-1:0] ext_addr,
    input  logic [31:0]       ext_wdata,
    output logic [31:0]       ext_rdata,

    // Porta B: Acesso do controlador/motor AES (quando MEM_SEL_AES == 1)
    input  logic              aes_en,
    input  logic              aes_we,
    input  logic [ADDR_W-1:0] aes_addr,
    input  logic [31:0]       aes_wdata,
    output logic [31:0]       aes_rdata,

    // Seleção de dono da memória (0 = externo/SPI, 1 = AES)
    input  logic              mem_sel_aes
);

    logic [31:0] mem [0:DEPTH-1];

    logic              sel_en;
    logic              sel_we;
    logic [ADDR_W-1:0] sel_addr;
    logic [31:0]       sel_wdata;
    logic [31:0]       mem_q;

    // Arbitragem determinística por MEM_SEL_AES
    always_comb begin
        if (mem_sel_aes) begin
            sel_en    = aes_en;
            sel_we    = aes_we;
            sel_addr  = aes_addr;
            sel_wdata = aes_wdata;
        end else begin
            sel_en    = ext_en;
            sel_we    = ext_we;
            sel_addr  = ext_addr;
            sel_wdata = ext_wdata;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_q <= 32'h0;
        end else if (sel_en) begin
            if (sel_we) begin
                mem[sel_addr] <= sel_wdata;
            end
            mem_q <= mem[sel_addr];
        end
    end

    assign ext_rdata = (!mem_sel_aes) ? mem_q : 32'h0;
    assign aes_rdata = ( mem_sel_aes) ? mem_q : 32'h0;

endmodule
