module tb_dummy_top;

    logic clk;
    logic rst_n;
    logic ready;

    dummy_top dut (
        .clk  (clk),
        .rst_n(rst_n),
        .ready(ready)
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        rst_n = 0;
        #20 rst_n = 1;
        #50;
        
        if (ready === 1'b1) begin
            $display("\n==========================================");
            $display("[SUCCESS] Ambiente Synopsys (VCS) configurado!");
            $display("==========================================\n");
        end else begin
            $display("\n[ERROR] Falha na simulação mínima.\n");
        end
        $finish;
    end

endmodule
