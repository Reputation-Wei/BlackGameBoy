module clk_div(
    input clk,
    input rst_n,
    output reg cpu_clk = 0
);


reg [6:0] clk_div_cnt = 0; // 7bit counter

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_div_cnt <= 0;
        cpu_clk <= 0;
    end else begin
        if (clk_div_cnt == 11) begin // 100MHz/12 ≈ 8.3333MHz
            clk_div_cnt <= 0;
            cpu_clk <= ~cpu_clk; // cpu_clk = 8.3333MHz/2 = 4.1666MHz
        end else begin
            clk_div_cnt <= clk_div_cnt + 1;
        end
    end
end

endmodule