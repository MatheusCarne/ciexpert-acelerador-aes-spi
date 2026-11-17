// ============================================================================
// minisoc_aes_top.sv
// Top-level do núcleo AES-128: Integra FSM de Controle, Key Expansion e Datapath.
// ============================================================================
module minisoc_aes_top (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         start_i,      // Pulso para iniciar cifragem/decriptação
  input  logic         enc_dec_i,    // 1: Cifragem (Cipher), 0: Decriptação (InvCipher)
  input  logic [127:0] key_i,        // Chave mestre de 128 bits
  input  logic [127:0] data_i,       // Bloco de entrada (Plaintext ou Ciphertext)
  output logic [127:0] data_o,       // Bloco de saída processado
  output logic         busy_o,       // 1 quando o acelerador estiver ocupado
  output logic         done_o        // Pulso de 1 ciclo indicando conclusão
);

  // Estados da FSM
  typedef enum logic [2:0] {
    IDLE        = 3'b000,
    LOAD_CYCLE  = 3'b001, // Ciclo 0: AddRoundKey inicial
    ROUND_LOOP  = 3'b010, // Rodadas 1 a 9
    FINAL_ROUND = 3'b011, // Rodada 10 (com bypass de MixColumns)
    DONE        = 3'b100  // Estado de conclusão
  } state_t;

  state_t state_q, state_d;

  // Registrador de Estado do Bloco
  logic [127:0] block_reg_q, block_reg_d;
  
  // Contador de Rodadas (0 a 10)
  logic [3:0]   round_cnt_q, round_cnt_d;

  // Sinais de Conexão com Submódulos
  logic [127:0] round_keys [0:10];
  logic [127:0] dp_out;
  logic [127:0] current_rkey;

  // Sinais de Controle do Datapath
  logic         load_cycle;
  logic         bypass_mc;

  // --------------------------------------------------------------------------
  // 1. Instanciação da Expansão de Chaves (Gera K0..K10 combinacionalmente)
  // --------------------------------------------------------------------------
  minisoc_aes_key_exp u_key_exp (
    .key_i        (key_i),
    .round_keys_o (round_keys)
  );

  // --------------------------------------------------------------------------
  // 2. Instanciação do Datapath Combinacional
  // --------------------------------------------------------------------------
  minisoc_aes_dp u_dp (
    .state_i      (block_reg_q),
    .rkey_i       (current_rkey),
    .enc_dec_i    (enc_dec_i),
    .bypass_mc_i  (bypass_mc),
    .load_cycle_i (load_cycle),
    .state_o      (dp_out)
  );

  // --------------------------------------------------------------------------
  // 3. Seleção de Subchave por Rodada (Direção Certa para Cipher / InvCipher)
  // --------------------------------------------------------------------------
  // Na Cifragem: usa K0 até K10 em ordem crescente.
  // Na Decriptação: usa K10 até K0 em ordem decrescente.
  always_comb begin
    if (enc_dec_i) begin
      current_rkey = round_keys[round_cnt_q];
    end else begin
      current_rkey = round_keys[10 - round_cnt_q];
    end
  end

  // --------------------------------------------------------------------------
  // 4. Lógica Sequencial da FSM
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q     <= IDLE;
      block_reg_q <= '0;
      round_cnt_q <= '0;
    end else begin
      state_q     <= state_d;
      block_reg_q <= block_reg_d;
      round_cnt_q <= round_cnt_d;
    end
  end

  // --------------------------------------------------------------------------
  // 5. Lógica Combinacional da FSM (Próximo Estado e Atribuições)
  // --------------------------------------------------------------------------
  always_comb begin
    // Valores padrão
    state_d      = state_q;
    block_reg_d  = block_reg_q;
    round_cnt_d  = round_cnt_q;
    busy_o       = 1'b1;
    done_o       = 1'b0;
    load_cycle   = 1'b0;
    bypass_mc    = 1'b0;

    unique case (state_q)
      IDLE: begin
        busy_o = 1'b0;
        if (start_i) begin
          block_reg_d = data_i;
          round_cnt_d = 4'd0;
          state_d     = LOAD_CYCLE;
        end
      end

      LOAD_CYCLE: begin
        load_cycle  = 1'b1;       // Ativa o AddRoundKey inicial (Ciclo 0)
        block_reg_d = dp_out;     // Atualiza o registrador com a saída do datapath
        round_cnt_d = 4'd1;       // Prepara para a rodada 1
        state_d     = ROUND_LOOP;
      end

      ROUND_LOOP: begin
        load_cycle  = 1'b0;
        bypass_mc   = 1'b0;
        block_reg_d = dp_out;

        if (round_cnt_q == 4'd9) begin
          state_d     = FINAL_ROUND; // Próxima rodada é a 10ª (última)
        end else begin
          round_cnt_d = round_cnt_q + 4'd1;
        end
      end

      FINAL_ROUND: begin
        load_cycle  = 1'b0;
        bypass_mc   = 1'b1;       // Ativa o bypass do (Inv)MixColumns na 10ª rodada
        block_reg_d = dp_out;
        state_d     = DONE;
      end

      DONE: begin
        done_o  = 1'b1;           // Sinaliza conclusão por 1 ciclo de clock
        busy_o  = 1'b0;
        state_d = IDLE;
      end

      default: state_d = IDLE;
    endcase
  end

  // Saída final mapeada diretamente do registrador de estado
  assign data_o = block_reg_q;

endmodule
