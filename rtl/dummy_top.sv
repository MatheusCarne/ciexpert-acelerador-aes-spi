module dummy_top (
    input  logic clk,
    input  logic rst_n,
    output logic ready
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else begin
            ready <= 1'b1;
        end
    end

endmodule
