module decoder (
    input wire [7:0] opcode,
    output reg [3:0] alu_op,
    output reg [2:0] reg_src,
    output reg [2:0] reg_dst,
    output reg [1:0] reg_pair,
    output reg imm_en,
    output reg [1:0] mem_op,
    output reg [1:0] branch_type,
    output reg [1:0] stack_op,
    output reg [2:0] interrupt_type
);

    // 指令类型定义
    localparam NOP = 8'h00;
    localparam LD_BC_nn = 8'h01;
    localparam LD_BC_A = 8'h02;
    localparam INC_BC = 8'h03;
    localparam INC_B = 8'h04;
    localparam DEC_B = 8'h05;
    localparam LD_B_n = 8'h06;
    localparam RLCA = 8'h07;
    // ... 更多指令定义

    always @(*) begin
        // 默认值
        alu_op = 4'b0000;
        reg_src = 3'b000;
        reg_dst = 3'b000;
        reg_pair = 2'b00;
        imm_en = 1'b0;
        mem_op = 2'b00;
        branch_type = 2'b00;
        stack_op = 2'b00;
        interrupt_type = 3'b000;

        case (opcode)
            NOP: begin
                // 无操作
            end

            LD_BC_nn: begin
                reg_pair = 2'b00;  // BC
                imm_en = 1'b1;
            end

            LD_BC_A: begin
                reg_src = 3'b000;  // A
                reg_pair = 2'b00;  // BC
                mem_op = 2'b01;    // 写内存
            end

            INC_BC: begin
                reg_pair = 2'b00;  // BC
                alu_op = 4'b1000;  // INC
            end

            INC_B: begin
                reg_dst = 3'b001;  // B
                alu_op = 4'b1000;  // INC
            end

            DEC_B: begin
                reg_dst = 3'b001;  // B
                alu_op = 4'b1001;  // DEC
            end

            LD_B_n: begin
                reg_dst = 3'b001;  // B
                imm_en = 1'b1;
            end

            RLCA: begin
                reg_dst = 3'b000;  // A
                alu_op = 4'b1010;  // RLC
            end

            // ... 更多指令解码
        endcase
    end

endmodule 