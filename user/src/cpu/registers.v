module registers (
    input wire clk,
    input wire rst_n,
    input wire [2:0] reg_addr,    // 寄存器地址
    input wire [7:0] data_in,     // 数据输入
    input wire write_en,          // 写使能
    output reg [7:0] data_out,    // 数据输出
    input wire [1:0] reg_pair,    // 寄存器对选择
    input wire [15:0] pair_data_in,// 16位数据输入
    input wire pair_write_en,     // 寄存器对写使能
    output reg [15:0] pair_data_out// 16位数据输出
);

    // 寄存器定义
    reg [7:0] regs [0:7];  // A, B, C, D, E, H, L, F

    // 8位寄存器读写
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            regs[0] <= 8'h00;  // A 111 ?????
            regs[1] <= 8'h00;  // B 000
            regs[2] <= 8'h00;  // C 001
            regs[3] <= 8'h00;  // D 010
            regs[4] <= 8'h00;  // E 011
            regs[5] <= 8'h00;  // H 100
            regs[6] <= 8'h00;  // L 101
            regs[7] <= 8'h00;  // F 110 ???
        end else if (write_en) begin
            regs[reg_addr] <= data_in;
        end
    end

    // 数据输出
    always @(*) begin
        data_out = regs[reg_addr];
    end

    // 16位寄存器对操作
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pair_data_out <= 16'h0000;
        end else if (pair_write_en) begin
            case (reg_pair)
                2'b00: begin  // BC
                    regs[1] <= pair_data_in[15:8];
                    regs[2] <= pair_data_in[7:0];
                end
                2'b01: begin  // DE
                    regs[3] <= pair_data_in[15:8];
                    regs[4] <= pair_data_in[7:0];
                end
                2'b10: begin  // HL
                    regs[5] <= pair_data_in[15:8];
                    regs[6] <= pair_data_in[7:0];
                end
                2'b11: begin  // AF
                    regs[0] <= pair_data_in[15:8];
                    regs[7] <= pair_data_in[7:0];
                end
            endcase
        end
    end

    // 16位数据输出
    always @(*) begin
        case (reg_pair)
            2'b00: pair_data_out = {regs[1], regs[2]};  // BC
            2'b01: pair_data_out = {regs[3], regs[4]};  // DE
            2'b10: pair_data_out = {regs[5], regs[6]};  // HL
            2'b11: pair_data_out = {regs[0], regs[7]};  // AF
        endcase
    end

endmodule 