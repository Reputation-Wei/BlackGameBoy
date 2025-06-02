module decoder (
    input wire [7:0] opcode,
    output reg [4:0] alu_op,
    output reg [2:0] reg_src, //source register
    output reg [2:0] reg_dst, //destination register
    output reg [1:0] reg_pair, //reg bc, de, hl, sp
    output reg imm_en, //immediate enable
    output reg [1:0] mem_op, //memory operation
    output reg [1:0] branch_type, //branch type
    output reg [1:0] stack_op, //stack operation
    output reg [2:0] interrupt_type //interrupt type
    // total 22 control signals 
    //output reg [21:0] control_words
);
//control_words = {alu_op, reg_src, reg_dst, reg_pair, imm_en, mem_op, branch_type, stack_op, interrupt_type}
//////////////////////////////////////////////////////////////////////////////////////////////
    // instruction set
 localparam NOP = 8'h00;
// localparam LD_BC_n16 = 8'h01;
// localparam LD_aBC_A = 8'h02;
// localparam INC_BC = 8'h03;
 localparam INC_B = 8'h04;
 localparam DEC_B = 8'h05;
 localparam LD_B_n8 = 8'h06;
// localparam RLCA = 8'h07;
// localparam LD_aa16_SP = 8'h08; //a16 是什么？
// localparam ADD_HL_BC = 8'h09; 
// localparam LD_A_aBC = 8'h0A;
// localparam DEC_BC = 8'h0B;
 localparam INC_C = 8'h0C;
 localparam DEC_C = 8'h0D;
 localparam LD_C_n8 = 8'h0E;
 localparam RRCA = 8'h0F;
// localparam STOP_n8 = 8'h10;
// localparam LD_DE_n16 = 8'h11;
// localparam LD_aDE_A = 8'h12;
// localparam INC_DE = 8'h13;
// localparam INC_D = 8'h14;
// localparam DEC_D = 8'h15;
// localparam LD_D_n8 = 8'h16;
 localparam RLA = 8'h17;
// localparam JR_e8 = 8'h18;
// localparam ADD_HL_DE = 8'h19;
// localparam LD_A_aDE = 8'h1A;
// localparam DEC_DE = 8'h1B;
// localparam INC_E = 8'h1C;
// localparam DEC_E = 8'h1D;
// localparam LD_E_n8 = 8'h1E;
// localparam RRA = 8'h1F;
// localparam JR_NZ_e8 = 8'h20;
// localparam LD_HL_n16 = 8'h21;
 localparam LD_aHLp_A = 8'h22;//LD [HL+],A
// localparam INC_HL = 8'h23;
// localparam INC_H = 8'h24;
// localparam DEC_H = 8'h25;
// localparam LD_H_n8 = 8'h26;
// localparam DAA = 8'h27;
// localparam JR_Z_e8 = 8'h28;
// localparam ADD_HL_HL = 8'h29;
// localparam LD_A_aHLp = 8'h2A;
// localparam DEC_HL = 8'h2B;
// localparam INC_L = 8'h2C;
// localparam DEC_L = 8'h2D;
// localparam LD_L_n8 = 8'h2E;
 localparam CPL = 8'h2F;
// localparam JR_NC_e8 = 8'h30;
// localparam LD_SP_n16 = 8'h31;
 localparam LD_aHLm_A = 8'h32;//LD [HL-],A
// localparam INC_SP = 8'h33;
// localparam INC_aHL = 8'h34;//INC HL
// localparam DEC_aHL = 8'h35;//DEC HL
// localparam LD_aHL_n8 = 8'h36;
// localparam SCF = 8'h37;
// localparam JR_C_e8 = 8'h38;
// localparam ADD_HL_SP = 8'h39;
 localparam LD_A_aHLm = 8'h3A;//LD A,[HL-]
// localparam DEC_SP = 8'h3B;
 localparam INC_A = 8'h3C;
 localparam DEC_A = 8'h3D;
// localparam LD_A_n8 = 8'h3E;
// localparam CCF = 8'h3F;
// localparam LD_B_B = 8'h40;
 localparam LD_B_C = 8'h41;
// localparam LD_B_D = 8'h42;
// localparam LD_B_E = 8'h43;
// localparam LD_B_H = 8'h44;
// localparam LD_B_L = 8'h45;
// localparam LD_B_aHL = 8'h46;
 localparam LD_B_A = 8'h47;
 localparam LD_C_B = 8'h48;
// localparam LD_C_C = 8'h49;
// localparam LD_C_D = 8'h4A;
// localparam LD_C_E = 8'h4B;
// localparam LD_C_H = 8'h4C;
// localparam LD_C_L = 8'h4D;
// localparam LD_C_aHL = 8'h4E;
// localparam LD_C_A = 8'h4F;
// localparam LD_D_B = 8'h50;
// localparam LD_D_C = 8'h51;
// localparam LD_D_D = 8'h52;
// localparam LD_D_E = 8'h53;
// localparam LD_D_H = 8'h54;
// localparam LD_D_L = 8'h55;
// localparam LD_D_aHL = 8'h56;
// localparam LD_D_A = 8'h57;
// localparam LD_E_B = 8'h58;
// localparam LD_E_C = 8'h59;
// localparam LD_E_D = 8'h5A;
// localparam LD_E_E = 8'h5B;
// localparam LD_E_H = 8'h5C;
// localparam LD_E_L = 8'h5D;
// localparam LD_E_aHL = 8'h5E;
// localparam LD_E_A = 8'h5F;
// localparam LD_H_B = 8'h60;
// localparam LD_H_C = 8'h61;
// localparam LD_H_D = 8'h62;
// localparam LD_H_E = 8'h63;
// localparam LD_H_H = 8'h64;
// localparam LD_H_L = 8'h65;
// localparam LD_H_aHL = 8'h66;
// localparam LD_H_A = 8'h67;
// localparam LD_L_B = 8'h68;
// localparam LD_L_C = 8'h69;
// localparam LD_L_D = 8'h6A;
// localparam LD_L_E = 8'h6B;
// localparam LD_L_H = 8'h6C;
// localparam LD_L_L = 8'h6D;
// localparam LD_L_aHL = 8'h6E;
// localparam LD_L_A = 8'h6F;
// localparam LD_aHL_B = 8'h70;
// localparam LD_aHL_C = 8'h71;
// localparam LD_aHL_D = 8'h72;
// localparam LD_aHL_E = 8'h73;
// localparam LD_aHL_H = 8'h74;
// localparam LD_aHL_L = 8'h75;
 localparam HALT = 8'h76;
 localparam LD_aHL_A = 8'h77;
 localparam LD_A_B = 8'h78;
 localparam LD_A_C = 8'h79;
// localparam LD_A_D = 8'h7A;
// localparam LD_A_E = 8'h7B;
// localparam LD_A_H = 8'h7C;
// localparam LD_A_L = 8'h7D;
// localparam LD_A_aHL = 8'h7E;
// localparam LD_A_A = 8'h7F;
localparam ADD_A_B = 8'h80;
localparam ADD_A_C = 8'h81;
// localparam ADD_A_D = 8'h82;
// localparam ADD_A_E = 8'h83;
// localparam ADD_A_H = 8'h84;
// localparam ADD_A_L = 8'h85;
// localparam ADD_A_aHL = 8'h86;
// localparam ADD_A_A = 8'h87;
// localparam ADC_A_B = 8'h88;
// localparam ADC_A_C = 8'h89;
// localparam ADC_A_D = 8'h8A;
// localparam ADC_A_E = 8'h8B;
// localparam ADC_A_H = 8'h8C;
// localparam ADC_A_L = 8'h8D;
// localparam ADC_A_aHL = 8'h8E;
// localparam ADC_A_A = 8'h8F;
localparam SUB_A_B = 8'h90;
localparam SUB_A_C = 8'h91;
// localparam SUB_A_D = 8'h92;
// localparam SUB_A_E = 8'h93;
// localparam SUB_A_H = 8'h94;
// localparam SUB_A_L = 8'h95;
// localparam SUB_A_aHL = 8'h96;
// localparam SUB_A_A = 8'h97;
// localparam SBC_A_B = 8'h98;
// localparam SBC_A_C = 8'h99;
// localparam SBC_A_D = 8'h9A;
// localparam SBC_A_E = 8'h9B;
// localparam SBC_A_H = 8'h9C;
// localparam SBC_A_L = 8'h9D;
// localparam SBC_A_aHL = 8'h9E;
// localparam SBC_A_A = 8'h9F;
localparam AND_A_B = 8'hA0;
localparam AND_A_C = 8'hA1;
// localparam AND_A_D = 8'hA2;
// localparam AND_A_E = 8'hA3;
// localparam AND_A_H = 8'hA4;
// localparam AND_A_L = 8'hA5;
// localparam AND_A_aHL = 8'hA6;
// localparam AND_A_A = 8'hA7;
localparam XOR_A_B = 8'hA8;
localparam XOR_A_C = 8'hA9;
// localparam XOR_A_D = 8'hAA;
// localparam XOR_A_E = 8'hAB;
// localparam XOR_A_H = 8'hAC;
// localparam XOR_A_L = 8'hAD;
// localparam XOR_A_aHL = 8'hAE;
// localparam XOR_A_A = 8'hAF;
localparam OR_A_B = 8'hB0;
localparam OR_A_C = 8'hB1;
// localparam OR_A_D = 8'hB2;
// localparam OR_A_E = 8'hB3;
// localparam OR_A_H = 8'hB4;
// localparam OR_A_L = 8'hB5;
// localparam OR_A_aHL = 8'hB6;
// localparam OR_A_A = 8'hB7;
// localparam CP_A_B = 8'hB8;
// localparam CP_A_C = 8'hB9;
// localparam CP_A_D = 8'hBA;
// localparam CP_A_E = 8'hBB;
// localparam CP_A_H = 8'hBC;
// localparam CP_A_L = 8'hBD;
// localparam CP_A_aHL = 8'hBE;
// localparam CP_A_A = 8'hBF;
// localparam RET_NZ = 8'hC0;
// localparam POP_BC = 8'hC1;
localparam JP_NZ_a16 = 8'hC2;
localparam JP_a16 = 8'hC3;
// localparam CALL_NZ_a16 = 8'hC4;
// localparam PUSH_BC = 8'hC5;
// localparam ADD_A_n8 = 8'hC6;
// localparam RST_0x00 = 8'hC7;
// localparam RET_Z = 8'hC8;
localparam RET = 8'hC9;
localparam JP_Z_a16 = 8'hCA;
// localparam PREFIX_CB = 8'hCB;
// localparam CALL_Z_a16 = 8'hCC;
localparam CALL_a16 = 8'hCD;
// localparam ADC_A_n8 = 8'hCE;
// localparam RST_0x08 = 8'hCF;
// localparam RET_NC = 8'hD0;
// localparam POP_DE = 8'hD1;
// localparam JP_NC_a16 = 8'hD2;
localparam ILLEGAL_D3 = 8'hD3; //非法指令
// localparam CALL_NC_a16 = 8'hD4;
// localparam PUSH_DE = 8'hD5;
// localparam SUB_A_n8 = 8'hD6;
// localparam RST_0x10 = 8'hD7;
// localparam RET_C = 8'hD8;
// localparam RETI = 8'hD9;
// localparam JP_C_a16 = 8'hDA;
localparam ILLEGAL_DB = 8'hDB; //非法指令
// localparam CALL_C_a16 = 8'hDC;
// localparam ILLEGAL_DD = 8'hDD;
// localparam SBC_A_n8 = 8'hDE;
// localparam RST_0x18 = 8'hDF;
// localparam LDH_aa8_A = 8'hE0;
// localparam POP_HL = 8'hE1;
// localparam LDH_C_A = 8'hE2;
// localparam ILLEGAL_E3 = 8'hE3;
// localparam ILLEGAL_E4 = 8'hE4;
localparam PUSH_HL = 8'hE5;
// localparam AND_A_n8 = 8'hE6;
// localparam RST_0x20 = 8'hE7;
// localparam ADD_SP_e8 = 8'hE8;
// localparam JP_HL = 8'hE9;
// localparam LD_aa16_A = 8'hEA;
// localparam ILLEGAL_EB = 8'hEB;
// localparam ILLEGAL_EC = 8'hEC;
// localparam ILLEGAL_ED = 8'hED;
// localparam XOR_A_n8 = 8'hEE;
// localparam RST_0x28 = 8'hEF;
// localparam LDH_A_a8 = 8'hF0;
// localparam POP_AF = 8'hF1;
// localparam LDH_A_C = 8'hF2;
// localparam DI = 8'hF3;
// localparam ILLEGAL_F4 = 8'hF4;
localparam PUSH_AF = 8'hF5;
// localparam OR_A_n8 = 8'hF6;
// localparam RST_0x30 = 8'hF7;
// localparam LD_HL_SP_e8 = 8'hF8;
// localparam LD_SP_HL = 8'hF9;
// localparam LD_A_a16 = 8'hFA;
// localparam EI = 8'hFB;
// localparam ILLEGAL_FC = 8'hFC;
// localparam ILLEGAL_FD = 8'hFD;
// localparam CP_A_n8 = 8'hFE;
// localparam RST_0x38 = 8'hFF;

//////////////////////////////////////////////////////////////////////////////

    always @(*) begin
        // 默认值
        alu_op = 5'b11111;
        reg_src = 3'b000;
        reg_dst = 3'b000;
        reg_pair = 2'b00;
        imm_en = 1'b0;
        mem_op = 2'b00;
        branch_type = 2'b00;
        stack_op = 2'b00;
        interrupt_type = 3'b000;

        casez (opcode)
            NOP: begin
                // 无操作
            end

            // LD_BC_n16: begin
            //     reg_pair = 2'b00;  // BC
            //     imm_en = 1'b1;
            // end

            // LD_aBC_A: begin
            //     reg_src = 3'b000;  // A
            //     reg_pair = 2'b00;  // BC
            //     mem_op = 2'b01;    // write to memory
            // end

            // INC_BC: begin
            //     reg_pair = 2'b00;  // BC
            //     alu_op = 4'b1000;  // INC
            // end
            8'b01???_???: begin  //for instruction LD Load register from register
                reg_pair = 2'b00;  // BC
                reg_dst = opcode[2:0];
                reg_src = opcode[6:3];  //
            end
            INC_B: begin
                reg_dst = 3'b001;  // B
                alu_op = 4'b1000;  // INC
            end

            DEC_B: begin
                reg_dst = 3'b001;  // B
                alu_op = 4'b1001;  // DEC
            end

            LD_B_n8: begin
                reg_dst = 3'b001;  // B
                imm_en = 1'b1;
            end
            INC_C:begin 

            end
            DEC_C:begin 

            end
            LD_C_n8:begin 

            end
            RRCA:begin 

            end
            // RLCA: begin
            //     reg_dst = 3'b000;  // A
            //     alu_op = 4'b1010;  // RLC
            // end

            // ... 更多指令解码
        endcase
    end

endmodule 