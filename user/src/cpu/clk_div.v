// 时钟分频模块
module clk_div(
    input clk,
    input rst_n,
    output reg cpu_clk = 0
);


reg [6:0] clk_div_cnt = 0; // 7位计数器，最大127

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_div_cnt <= 0;
        cpu_clk <= 0;
    end else begin
        if (clk_div_cnt == 23) begin // 100MHz/24 ≈ 4.1666MHz
            clk_div_cnt <= 0;
            cpu_clk <= ~cpu_clk;
        end else begin
            clk_div_cnt <= clk_div_cnt + 1;
        end
    end
end

endmodule