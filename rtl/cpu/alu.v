module alu (
    input wire [7:0] a,          // 操作数A
    input wire [7:0] b,          // 操作数B
    input wire [3:0] op,         // 操作码
    input wire carry_in,         // 进位输入
    output reg [7:0] result,     // 运算结果
    output reg carry_out,        // 进位输出
    output reg half_carry_out,   // 半进位输出
    output reg zero_out,         // 零标志输出
    output reg subtract_out      // 减法标志输出
);

    // 操作码定义
    localparam ADD  = 4'b0000;   // 加法
    localparam ADC  = 4'b0001;   // 带进位加法
    localparam SUB  = 4'b0010;   // 减法
    localparam SBC  = 4'b0011;   // 带借位减法
    localparam AND  = 4'b0100;   // 与运算
    localparam XOR  = 4'b0101;   // 异或运算
    localparam OR   = 4'b0110;   // 或运算
    localparam CP   = 4'b0111;   // 比较
    localparam INC  = 4'b1000;   // 加1
    localparam DEC  = 4'b1001;   // 减1
    localparam RLC  = 4'b1010;   // 循环左移
    localparam RRC  = 4'b1011;   // 循环右移
    localparam RL   = 4'b1100;   // 通过进位左移
    localparam RR   = 4'b1101;   // 通过进位右移
    localparam SLA  = 4'b1110;   // 算术左移
    localparam SRA  = 4'b1111;   // 算术右移

    // 内部信号
    wire [8:0] add_result;
    wire [8:0] sub_result;
    wire [8:0] adc_result;
    wire [8:0] sbc_result;

    // 加法结果计算
    assign add_result = a + b;
    assign adc_result = a + b + carry_in;
    
    // 减法结果计算
    assign sub_result = a - b;
    assign sbc_result = a - b - carry_in;

    always @(*) begin
        case (op)
            ADD: begin
                result = add_result[7:0];
                carry_out = add_result[8];
                half_carry_out = (a[3:0] + b[3:0]) > 4'hF;
                subtract_out = 0;
            end
            
            ADC: begin
                result = adc_result[7:0];
                carry_out = adc_result[8];
                half_carry_out = (a[3:0] + b[3:0] + carry_in) > 4'hF;
                subtract_out = 0;
            end
            
            SUB: begin
                result = sub_result[7:0];
                carry_out = sub_result[8];
                half_carry_out = a[3:0] < b[3:0];
                subtract_out = 1;
            end
            
            SBC: begin
                result = sbc_result[7:0];
                carry_out = sbc_result[8];
                half_carry_out = a[3:0] < (b[3:0] + carry_in);
                subtract_out = 1;
            end
            
            AND: begin
                result = a & b;
                carry_out = 0;
                half_carry_out = 1;
                subtract_out = 0;
            end
            
            XOR: begin
                result = a ^ b;
                carry_out = 0;
                half_carry_out = 0;
                subtract_out = 0;
            end
            
            OR: begin
                result = a | b;
                carry_out = 0;
                half_carry_out = 0;
                subtract_out = 0;
            end
            
            CP: begin
                result = a;  // 保持A不变
                carry_out = sub_result[8];
                half_carry_out = a[3:0] < b[3:0];
                subtract_out = 1;
            end
            
            INC: begin
                result = a + 1;
                carry_out = carry_in;
                half_carry_out = a[3:0] == 4'hF;
                subtract_out = 0;
            end
            
            DEC: begin
                result = a - 1;
                carry_out = carry_in;
                half_carry_out = a[3:0] == 4'h0;
                subtract_out = 1;
            end
            
            // 移位操作
            RLC: begin
                result = {a[6:0], a[7]};
                carry_out = a[7];
                half_carry_out = 0;
                subtract_out = 0;
            end
            
            RRC: begin
                result = {a[0], a[7:1]};
                carry_out = a[0];
                half_carry_out = 0;
                subtract_out = 0;
            end
            
            RL: begin
                result = {a[6:0], carry_in};
                carry_out = a[7];
                half_carry_out = 0;
                subtract_out = 0;
            end
            
            RR: begin
                result = {carry_in, a[7:1]};
                carry_out = a[0];
                half_carry_out = 0;
                subtract_out = 0;
            end
            
            SLA: begin
                result = {a[6:0], 1'b0};
                carry_out = a[7];
                half_carry_out = 0;
                subtract_out = 0;
            end
            
            SRA: begin
                result = {a[7], a[7:1]};
                carry_out = a[0];
                half_carry_out = 0;
                subtract_out = 0;
            end
            
            default: begin
                result = 8'h00;
                carry_out = 0;
                half_carry_out = 0;
                subtract_out = 0;
            end
        endcase
        
        // 零标志计算
        zero_out = (result == 8'h00);
    end

endmodule 