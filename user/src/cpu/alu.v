module alu (
    input wire [7:0] a,          // Operand A
    input wire [7:0] b,          // Operand B
    input wire [4:0] op,         // Operation code
    input wire carry_in,         // Carry input (C flag)
    output reg [7:0] result,     // Calculation result
    output reg Z_flag,           // Zero flag (Z)
    output reg N_flag,           // Subtract flag (N)
    output reg H_flag,           // Half Carry flag (H)
    output reg C_flag            // Carry flag (C)
);

    // Operation code definitions
    localparam ADD  = 5'b00000;   // Addition
    localparam ADC  = 5'b00001;   // Add with Carry
    localparam SUB  = 5'b00010;   // Subtraction
    localparam SBC  = 5'b00011;   // Subtract with Carry (borrow)
    localparam AND  = 5'b00100;   // Logical AND
    localparam XOR  = 5'b00101;   // Logical XOR
    localparam OR   = 5'b00110;   // Logical OR
    localparam CP   = 5'b00111;   // Compare (A - B)
    localparam INC  = 5'b01000;   // Increment A
    localparam DEC  = 5'b01001;   // Decrement A
    localparam RLC  = 5'b01010;   // Rotate Left Circular
    localparam RRC  = 5'b01011;   // Rotate Right Circular
    localparam RL   = 5'b01100;   // Rotate Left through Carry
    localparam RR   = 5'b01101;   // Rotate Right through Carry
    localparam SLA  = 5'b01110;   // Shift Left Arithmetic
    localparam SRA  = 5'b01111;   // Shift Right Arithmetic

    // Internal signals for extended results
    wire [8:0] add_result_ext;
    wire [8:0] adc_result_ext;
    wire [8:0] sub_result_ext;
    wire [8:0] sbc_result_ext;

    assign add_result_ext = {1'b0, a} + {1'b0, b};
    assign adc_result_ext = {1'b0, a} + {1'b0, b} + {8'b0, carry_in};
    assign sub_result_ext = {1'b0, a} - {1'b0, b};
    assign sbc_result_ext = {1'b0, a} - {1'b0, b} - {8'b0, carry_in};

    always @(*) begin
        // Default values
        result = 8'h00;
        Z_flag = 1'b0;
        N_flag = 1'b0;
        H_flag = 1'b0;
        C_flag = 1'b0;

        case (op)
            ADD: begin
                result = add_result_ext[7:0];
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = ((a & 4'hF) + (b & 4'hF)) > 4'hF;
                C_flag = add_result_ext[8];
            end
            ADC: begin
                result = adc_result_ext[7:0];
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = ((a & 4'hF) + (b & 4'hF) + carry_in) > 4'hF;
                C_flag = adc_result_ext[8];
            end
            SUB: begin
                result = sub_result_ext[7:0];
                Z_flag = (result == 8'h00);
                N_flag = 1'b1;
                H_flag = (a & 4'hF) < (b & 4'hF);
                C_flag = sub_result_ext[8];
            end
            SBC: begin
                result = sbc_result_ext[7:0];
                Z_flag = (result == 8'h00);
                N_flag = 1'b1;
                H_flag = (a & 4'hF) < ((b & 4'hF) + carry_in);
                C_flag = sbc_result_ext[8];
            end
            AND: begin
                result = a & b;
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b1; // Always set for AND
                C_flag = 1'b0;
            end
            XOR: begin
                result = a ^ b;
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = 1'b0;
            end
            OR: begin
                result = a | b;
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = 1'b0;
            end
            CP: begin
                // Compare does not store result, only sets flags as if SUB was performed
                result = a; // Not used, just for completeness
                Z_flag = ((a - b) == 8'h00);
                N_flag = 1'b1;
                H_flag = (a & 4'hF) < (b & 4'hF);
                C_flag = (a < b);
            end
            INC: begin
                result = a + 1;
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = ((a & 4'hF) + 1) > 4'hF;
                // C_flag is not affected by INC (should remain unchanged in CPU)
            end
            DEC: begin
                result = a - 1;
                Z_flag = (result == 8'h00);
                N_flag = 1'b1;
                H_flag = (a & 4'hF) == 4'h0;
                // C_flag is not affected by DEC (should remain unchanged in CPU)
            end
            RLC: begin
                result = {a[6:0], a[7]};
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = a[7];
            end
            RRC: begin
                result = {a[0], a[7:1]};
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = a[0];
            end
            RL: begin
                result = {a[6:0], carry_in};
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = a[7];
            end
            RR: begin
                result = {carry_in, a[7:1]};
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = a[0];
            end
            SLA: begin
                result = {a[6:0], 1'b0};
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = a[7];
            end
            SRA: begin
                result = {a[7], a[7:1]};
                Z_flag = (result == 8'h00);
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = a[0];
            end
            default: begin
                result = 8'h00;
                Z_flag = 1'b1;
                N_flag = 1'b0;
                H_flag = 1'b0;
                C_flag = 1'b0;
            end
        endcase
    end

endmodule 