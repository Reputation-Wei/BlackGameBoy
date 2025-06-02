// gb_cpu.v
// GameBoy DMG CPU (Sharp LR35902)
// Simplified implementation for demonstration

module gb_cpu (
    input wire          clk,          // System clock (T-cycle clock)
    input wire          rst_n,        // Asynchronous reset, active low

    // Memory Interface
    output reg [15:0]   addr_bus,     // Address bus
    input wire [7:0]    data_bus_in,  // Data bus from memory
    output wire [7:0]   data_bus_out, // Data bus to memory
    output wire         mem_rd_en,    // Memory read enable
    output wire         mem_wr_en,    // Memory write enable

    // Interrupt Interface
    input wire          irq_vblank,   // VBlank interrupt request
    input wire          irq_lcd_stat, // LCD STAT interrupt request
    input wire          irq_timer,    // Timer interrupt request
    input wire          irq_serial,   // Serial interrupt request
    input wire          irq_joypad    // Joypad interrupt request
);

//------------------------------------------------------------------------------
// Parameters & Localparams
//------------------------------------------------------------------------------
    // State machine states
    localparam S_FETCH_OPCODE  = 4'd0;
    localparam S_DECODE_EXEC   = 4'd1;
    localparam S_MEM_READ_OP1  = 4'd2; // Read 1st byte of operand
    localparam S_MEM_READ_OP2  = 4'd3; // Read 2nd byte of operand
    localparam S_MEM_WRITE_VAL = 4'd4; // Write value to memory
    localparam S_MEM_READ_VAL  = 4'd5; // Read value from memory
    localparam S_EXECUTE_MULTI = 4'd6; // Multi-cycle execution step
    localparam S_PUSH_PCH      = 4'd7;
    localparam S_PUSH_PCL      = 4'd8;
    localparam S_POP_PCL       = 4'd9;
    localparam S_POP_PCH       = 4'd10;
    localparam S_IRQ_CHECK     = 4'd11;
    localparam S_IRQ_SEQ_1     = 4'd12; // Push PCH
    localparam S_IRQ_SEQ_2     = 4'd13; // Push PCL
    localparam S_IRQ_SEQ_3     = 4'd14; // Jump to handler (dummy cycle)
    localparam S_IRQ_SEQ_4     = 4'd15; // Jump to handler (actual jump)

    // Flag bits in F register (Z N H C 0 0 0 0)
    localparam FLAG_Z_BIT = 7; // Zero flag
    localparam FLAG_N_BIT = 6; // Subtract flag
    localparam FLAG_H_BIT = 5; // Half Carry flag
    localparam FLAG_C_BIT = 4; // Carry flag

//------------------------------------------------------------------------------
// Registers
//------------------------------------------------------------------------------
    // 8-bit Registers
    reg [7:0] reg_a;
    reg [7:0] reg_f; // Flags: Z N H C 0 0 0 0
    reg [7:0] reg_b;
    reg [7:0] reg_c;
    reg [7:0] reg_d;
    reg [7:0] reg_e;
    reg [7:0] reg_h;
    reg [7:0] reg_l;

    // 16-bit Registers
    reg [15:0] reg_pc; // Program Counter
    reg [15:0] reg_sp; // Stack Pointer

    // Internal registers for instruction processing
    reg [7:0] opcode;
    reg [7:0] operand1; // First byte of operand (e.g., n, or low byte of nn)
    reg [7:0] operand2; // Second byte of operand (e.g., high byte of nn)
    reg [7:0] alu_result;
    reg [15:0] addr_temp; // Temporary address for memory operations
    reg [7:0] data_temp;  // Temporary data for memory operations

    // CPU state
    reg [3:0] current_state;
    reg [3:0] next_state;

    // M-cycle counter (for timing control within an instruction)
    // Each instruction specifies total M-cycles.
    // 1 M-cycle = 4 T-cycles. We advance state per T-cycle, but logic relates to M-cycles.
    reg [2:0] t_cycle_count; // Counts T-cycles within an M-cycle (0-3)
    reg       m_cycle_done;  // Indicates an M-cycle has completed

    // Interrupt control
    reg       ime_flag;     // Interrupt Master Enable
    reg [4:0] ie_reg;       // Interrupt Enable Register (0xFFFF) - model as internal for now
    reg [4:0] if_reg;       // Interrupt Flag Register (0xFF0F) - model as internal for now
    reg       halt_mode;
    reg       stop_mode;    // Not fully implemented

    // Flags (easier to work with individually)
    wire      flag_z;
    wire      flag_n;
    wire      flag_h;
    wire      flag_c;

    assign flag_z = reg_f[FLAG_Z_BIT];
    assign flag_n = reg_f[FLAG_N_BIT];
    assign flag_h = reg_f[FLAG_H_BIT];
    assign flag_c = reg_f[FLAG_C_BIT];

//------------------------------------------------------------------------------
// Memory Interface Signals
//------------------------------------------------------------------------------
    // Internal signals for controlling memory access
    reg mem_rd_en_internal;
    reg mem_wr_en_internal;
    reg [7:0] data_bus_out_internal;

    assign mem_rd_en = mem_rd_en_internal;
    assign mem_wr_en = mem_wr_en_internal;
    assign data_bus_out = data_bus_out_internal;

//------------------------------------------------------------------------------
// T-Cycle and M-Cycle Management
//------------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t_cycle_count <= 3'b0; // Start at T0 of M1
            m_cycle_done <= 1'b0;
        end else begin
            if (t_cycle_count == 3'd3) begin
                t_cycle_count <= 3'b0;
                m_cycle_done  <= 1'b1; // M-cycle completes at the end of T3
            end else begin
                t_cycle_count <= t_cycle_count + 1;
                m_cycle_done  <= 1'b0;
            end
        end
    end

//------------------------------------------------------------------------------
// Main State Machine & Registers Update
//------------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset values for GameBoy DMG
            reg_a  <= 8'h01; // Or 8'h11 if CGB mode was enabled, but this is DMG
            reg_f  <= 8'hB0; // Z=1, N=0, H=1, C=1 (depends on boot ROM)
            reg_b  <= 8'h00;
            reg_c  <= 8'h13;
            reg_d  <= 8'h00;
            reg_e  <= 8'hD8;
            reg_h  <= 8'h01;
            reg_l  <= 8'h4D;
            reg_pc <= 16'h0100; // After boot ROM
            reg_sp <= 16'hFFFE;

            current_state <= S_FETCH_OPCODE;
            ime_flag      <= 1'b0; // IME is disabled on boot
            halt_mode     <= 1'b0;
            stop_mode     <= 1'b0;
            // Actual IE/IF are memory mapped, for simplicity treat as internal here.
            // Real IE and IF are at 0xFFFF and 0xFF0F.
            // For a full model, writes to these addresses update these regs.
            ie_reg        <= 5'b00000; 
            if_reg        <= 5'b00000; // Or some initial value reflecting boot state

            opcode        <= 8'h00; // NOP
            operand1      <= 8'h00;
            operand2      <= 8'h00;

        end else begin
            // Default: keep current values unless changed by instruction
            reg_a  <= reg_a;
            reg_f  <= reg_f;
            reg_b  <= reg_b;
            reg_c  <= reg_c;
            reg_d  <= reg_d;
            reg_e  <= reg_e;
            reg_h  <= reg_h;
            reg_l  <= reg_l;
            reg_pc <= reg_pc;
            reg_sp <= reg_sp;
            ime_flag <= ime_flag;
            halt_mode <= halt_mode;
            // ie_reg and if_reg would be updated by memory writes in a full system

            // Update IF bits based on external IRQ lines (simplified)
            // In a real system, IF bits are set by hardware and cleared by software or ISR entry.
            // This is a very simplified model for testing.
            if_reg[0] <= if_reg[0] | irq_vblank; 
            if_reg[1] <= if_reg[1] | irq_lcd_stat;
            if_reg[2] <= if_reg[2] | irq_timer;
            if_reg[3] <= if_reg[3] | irq_serial;
            if_reg[4] <= if_reg[4] | irq_joypad;

            if (m_cycle_done) begin // State transitions happen on M-cycle boundaries
                current_state <= next_state;

                // Register updates that happen at M-cycle boundaries (based on current_state actions)
                case (current_state) // Actions *completed* in this M-cycle
                    S_FETCH_OPCODE: begin
                        opcode <= data_bus_in;
                        reg_pc <= reg_pc + 1;
                    end
                    S_MEM_READ_OP1: begin
                        operand1 <= data_bus_in;
                        reg_pc   <= reg_pc + 1;
                    end
                    S_MEM_READ_OP2: begin
                        operand2 <= data_bus_in;
                        reg_pc   <= reg_pc + 1;
                    end
                    S_MEM_READ_VAL: begin
                        data_temp <= data_bus_in; // Store read value for use in next EXECUTE state
                    end
                    S_IRQ_SEQ_1: begin // Pushed PCH
                        reg_sp <= reg_sp - 1;
                    end
                    S_IRQ_SEQ_2: begin // Pushed PCL
                        reg_sp <= reg_sp - 1;
                        ime_flag <= 1'b0; // IME is cleared
                        // Clear the specific IF bit for the handled interrupt (simplification: highest priority)
                        if (ie_reg[0] & if_reg[0]) if_reg[0] <= 1'b0;
                        else if (ie_reg[1] & if_reg[1]) if_reg[1] <= 1'b0;
                        else if (ie_reg[2] & if_reg[2]) if_reg[2] <= 1'b0;
                        else if (ie_reg[3] & if_reg[3]) if_reg[3] <= 1'b0;
                        else if (ie_reg[4] & if_reg[4]) if_reg[4] <= 1'b0;
                    end
                    S_IRQ_SEQ_4: begin // Actual jump to ISR
                        if (ie_reg[0] & if_reg[0]) reg_pc <= 16'h0040;      // VBLANK
                        else if (ie_reg[1] & if_reg[1]) reg_pc <= 16'h0048; // LCD_STAT
                        else if (ie_reg[2] & if_reg[2]) reg_pc <= 16'h0050; // TIMER
                        else if (ie_reg[3] & if_reg[3]) reg_pc <= 16'h0058; // SERIAL
                        else if (ie_reg[4] & if_reg[4]) reg_pc <= 16'h0060; // JOYPAD
                    end
                    S_PUSH_PCH: reg_sp <= reg_sp - 1;
                    S_PUSH_PCL: reg_sp <= reg_sp - 1;
                    S_POP_PCL:  operand1 <= data_bus_in; // Store PCL
                    S_POP_PCH:  begin
                        operand2 <= data_bus_in; // Store PCH
                        reg_pc   <= {operand2, operand1}; // For RET
                    end

                    // Instructions update registers directly in S_DECODE_EXEC if they are 1 M-cycle
                    // Or at the end of their multi-M-cycle sequence
                    S_DECODE_EXEC: begin
                        // This state handles execution or sets up for multi-cycle execution
                        // Register updates for 1 M-cycle opcodes happen here (in combinatorial block below)
                        // For multi-cycle, they happen when their final M-cycle completes
                    end
                    S_EXECUTE_MULTI: begin
                        // Final step of a multi-cycle instruction might update registers here.
                    end
                    default:;
                endcase
            end
        end
    end

//------------------------------------------------------------------------------
// Next State Logic & Combinatorial Instruction Decode/Execute
//------------------------------------------------------------------------------
    always_comb begin
        // Default outputs
        next_state            = current_state; // Stay in current state if m_cycle_done is false
        addr_bus              = reg_pc;        // Default address is PC for fetch
        mem_rd_en_internal    = 1'b0;
        mem_wr_en_internal    = 1'b0;
        data_bus_out_internal = 8'h00;         // Default write data

        // Default register values (will be overridden by specific instructions)
        // These are combinational assignments for registers that are updated in the clocked block
        // This is for clarity, actual update is reg_x_next <= value; then reg_x <= reg_x_next;
        // But Verilog allows direct assignment in always_comb if the reg is clocked elsewhere.
        // To be strict, one would use `reg_a_next`, `reg_f_next` etc.
        // For this example, we will assign directly to reg_a, reg_f etc. and the clocked block will latch them.
        // This means the "next value" logic is embedded here.

        // --- Temporary variables for ALU and flag calculation ---
        reg [7:0] temp_a, temp_b, temp_c, temp_d, temp_e, temp_h, temp_l;
        reg [7:0] temp_f;
        reg [15:0] temp_pc, temp_sp;
        reg temp_ime;
        reg temp_halt;

        temp_a = reg_a; temp_b = reg_b; temp_c = reg_c; temp_d = reg_d;
        temp_e = reg_e; temp_h = reg_h; temp_l = reg_l; temp_f = reg_f;
        temp_pc = reg_pc; temp_sp = reg_sp;
        temp_ime = ime_flag; temp_halt = halt_mode;

        // --- ALU temporary results ---
        logic [8:0] alu_add_res; // For carry detection in 8-bit add
        logic [8:0] alu_adc_res;
        logic [8:0] alu_sub_res; // For borrow detection in 8-bit sub
        logic [8:0] alu_sbc_res;
        logic [3:0] alu_h_add_res; // For half-carry in add
        logic [3:0] alu_h_sub_res; // For half-carry in sub

        // --- Default flag settings for ALU ops (can be overridden) ---
        logic next_flag_z, next_flag_n, next_flag_h, next_flag_c;
        next_flag_z = flag_z; // Keep old flags unless operation changes them
        next_flag_n = flag_n;
        next_flag_h = flag_h;
        next_flag_c = flag_c;


        // --- Interrupt Check ---
        // Happens after every instruction execution.
        // If IME is true and (IE & IF) is non-zero, an interrupt should occur.
        // Priority: VBlank > LCD STAT > Timer > Serial > Joypad
        logic pending_irq;
        pending_irq = (ie_reg[0] & if_reg[0]) | (ie_reg[1] & if_reg[1]) |
                      (ie_reg[2] & if_reg[2]) | (ie_reg[3] & if_reg[3]) |
                      (ie_reg[4] & if_reg[4]);

        if (m_cycle_done) begin // Only transition states or start new instruction on M-cycle boundary
            case (current_state)
                S_FETCH_OPCODE: begin
                    mem_rd_en_internal = 1'b1; // Read opcode from PC
                    addr_bus           = reg_pc;
                    // `opcode` will be latched from data_bus_in by the clocked block
                    // `reg_pc` will be incremented by the clocked block
                    next_state         = S_DECODE_EXEC;
                    if (halt_mode && !pending_irq) begin // Stay halted if no pending IRQ
                        next_state = S_FETCH_OPCODE; // Effectively stalls fetching
                        addr_bus   = reg_pc -1; // Re-point to HALT instruction
                    end else if (halt_mode && pending_irq) begin
                        temp_halt = 1'b0; // Exit HALT mode if IRQ pending
                    end
                end

                S_DECODE_EXEC: begin
                    // This is the main decode hub. Many instructions complete in 1 M-cycle.
                    // Others transition to operand fetch or multi-cycle execution.
                    // The PC has already been incremented past the opcode.
                    // Default next state is to fetch next instruction if current one completes.
                    next_state = S_IRQ_CHECK; // After execution, check for interrupts

                    case (opcode)
                        // NOP (0x00) - 1 M-cycle (4T)
                        8'h00: begin
                            // Action: None
                            // Flags: No change
                            // PC already incremented
                            // M-Cycles: 1 (this one)
                        end

                        // LD BC, nn (0x01) - 3 M-cycles
                        8'h01: begin
                            next_state         = S_MEM_READ_OP1; // Fetch low byte for C
                            addr_bus           = reg_pc;         // From current PC
                            mem_rd_en_internal = 1'b1;
                            // C will be operand1, B will be operand2
                            // PC will be incremented in S_MEM_READ_OP1 and S_MEM_READ_OP2
                            // Actual LD BC happens after S_MEM_READ_OP2 completes.
                        end

                        // LD (BC), A (0x02) - 2 M-cycles
                        8'h02: begin
                            next_state            = S_MEM_WRITE_VAL;
                            addr_bus              = {reg_b, reg_c};
                            data_bus_out_internal = reg_a;
                            mem_wr_en_internal    = 1'b1;
                        end

                        // INC BC (0x03) - 2 M-cycles
                        8'h03: begin
                            {temp_b, temp_c} = {reg_b, reg_c} + 1;
                            // This instruction takes 2 M-cycles. This is M1 (decode).
                            // M2 is internal operation.
                            // For simplicity, we can do it in one effective state change if timing allows
                            // or force an S_EXECUTE_MULTI if strict 2 M-cycles are needed.
                            // GB spec says 8 T-cycles. First M-cycle is fetch/decode.
                            // Second M-cycle is internal operation. So, we need one more M-cycle.
                            next_state = S_EXECUTE_MULTI; // Represents the internal operation cycle
                        end

                        // INC B (0x04) - 1 M-cycle
                        8'h04: begin
                            temp_b      = reg_b + 1;
                            next_flag_z = (temp_b == 8'h00);
                            next_flag_n = 1'b0;
                            next_flag_h = ((reg_b & 8'h0F) + 1'b1) > 8'h0F;
                            // C not affected
                        end

                        // DEC B (0x05) - 1 M-cycle
                        8'h05: begin
                            temp_b      = reg_b - 1;
                            next_flag_z = (temp_b == 8'h00);
                            next_flag_n = 1'b1;
                            next_flag_h = (reg_b & 8'h0F) == 8'h00; // Borrow from bit 4
                            // C not affected
                        end

                        // LD B, n (0x06) - 2 M-cycles
                        8'h06: begin
                            next_state         = S_MEM_READ_OP1; // Fetch n for B
                            addr_bus           = reg_pc;
                            mem_rd_en_internal = 1'b1;
                            // B will be operand1
                        end

                        // RLCA (0x07) - 1 M-cycle
                        8'h07: begin
                            next_flag_c = temp_a[7];
                            temp_a      = {temp_a[6:0], temp_a[7]};
                            next_flag_z = 1'b0; // Z is reset for RLCA/RRCA/RLA/RRA
                            next_flag_n = 1'b0;
                            next_flag_h = 1'b0;
                        end

                        // LD (nn), SP (0x08) - 5 M-cycles
                        // M1: Fetch Opcode
                        // M2: Fetch nn_low -> operand1
                        // M3: Fetch nn_high -> operand2
                        // M4: Write SP_low to (nn)
                        // M5: Write SP_high to (nn+1)
                        8'h08: begin
                            next_state = S_MEM_READ_OP1; // Fetch nn_low
                            addr_bus   = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end

                        // ADD HL, BC (0x09) - 2 M-cycles
                        8'h09: begin
                            logic [16:0] sum_hl_bc;
                            logic [11:0] h_sum_hl_bc; // For half carry (bit 11 to 12)
                            sum_hl_bc   = {reg_h, reg_l} + {reg_b, reg_c};
                            h_sum_hl_bc = ({reg_h, reg_l} & 16'h0FFF) + ({reg_b, reg_c} & 16'h0FFF);

                            {temp_h, temp_l} = sum_hl_bc[15:0];
                            // N is reset
                            next_flag_n = 1'b0;
                            // H is set if carry from bit 11
                            next_flag_h = h_sum_hl_bc[12];
                            // C is set if carry from bit 15
                            next_flag_c = sum_hl_bc[16];
                            // Z not affected
                            next_state = S_EXECUTE_MULTI; // 2nd M-cycle for internal op
                        end

                        // LD A, (BC) (0x0A) - 2 M-cycles
                        8'h0A: begin
                            next_state         = S_MEM_READ_VAL;
                            addr_bus           = {reg_b, reg_c};
                            mem_rd_en_internal = 1'b1;
                            // temp_a will be updated from data_temp after read completes
                        end
                        
                        // LD A, n (0x3E) - 2 M-cycles
                        8'h3E: begin
                            next_state         = S_MEM_READ_OP1; // Fetch n for A
                            addr_bus           = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end

                        // LD B,A (0x47)
                        8'h47: temp_b = reg_a; // 1 M-cycle
                        // LD C,A (0x4F)
                        8'h4F: temp_c = reg_a; // 1 M-cycle
                        // ... many more LD r, r' instructions ...
                        // LD H,L (0x65)
                        8'h65: temp_h = reg_l;
                        // LD L,H (0x6C)
                        8'h6C: temp_l = reg_h;

                        // LD A,B (0x78)
                        8'h78: temp_a = reg_b; // 1 M-cycle
                        // LD A,C (0x79)
                        8'h79: temp_a = reg_c; // 1 M-cycle
                        // LD A,D (0x7A)
                        8'h7A: temp_a = reg_d; // 1 M-cycle
                        // LD A,E (0x7B)
                        8'h7B: temp_a = reg_e; // 1 M-cycle
                        // LD A,H (0x7C)
                        8'h7C: temp_a = reg_h; // 1 M-cycle
                        // LD A,L (0x7D)
                        8'h7D: temp_a = reg_l; // 1 M-cycle
                        // LD A,(HL) (0x7E) - 2 M-cycles
                        8'h7E: begin
                            next_state         = S_MEM_READ_VAL;
                            addr_bus           = {reg_h, reg_l};
                            mem_rd_en_internal = 1'b1;
                        end
                        // LD A,A (0x7F) - is like NOP
                        8'h7F: temp_a = reg_a; // 1 M-cycle

                        // ADD A, B (0x80) - 1 M-cycle
                        8'h80: begin
                            alu_add_res = {1'b0, reg_a} + {1'b0, reg_b};
                            alu_h_add_res = (reg_a & 8'h0F) + (reg_b & 8'h0F);
                            temp_a      = alu_add_res[7:0];
                            next_flag_z = (temp_a == 8'h00);
                            next_flag_n = 1'b0;
                            next_flag_h = alu_h_add_res[4];
                            next_flag_c = alu_add_res[8];
                        end
                        // ... other ADD A, r ...
                        // ADD A, (HL) (0x86) - 2 M-cycles
                        8'h86: begin
                            next_state         = S_MEM_READ_VAL; // Read (HL) into data_temp
                            addr_bus           = {reg_h, reg_l};
                            mem_rd_en_internal = 1'b1;
                            // Actual ADD A, data_temp happens in S_EXECUTE_MULTI
                        end

                        // SUB B (0x90) - 1 M-cycle
                        8'h90: begin
                            alu_sub_res = {1'b0, reg_a} - {1'b0, reg_b};
                            alu_h_sub_res = (reg_a & 8'h0F) - (reg_b & 8'h0F);
                            temp_a      = alu_sub_res[7:0];
                            next_flag_z = (temp_a == 8'h00);
                            next_flag_n = 1'b1;
                            next_flag_h = alu_h_sub_res[4]; // Borrow from bit 4
                            next_flag_c = alu_sub_res[8]; // Borrow
                        end
                        // ... other SUB r ...

                        // AND B (0xA0) - 1 M-cycle
                        8'hA0: begin
                            temp_a      = reg_a & reg_b;
                            next_flag_z = (temp_a == 8'h00);
                            next_flag_n = 1'b0;
                            next_flag_h = 1'b1; // AND sets H
                            next_flag_c = 1'b0;
                        end
                        // ... other AND r ...

                        // XOR B (0xA8) - 1 M-cycle
                        8'hA8: begin
                            temp_a      = reg_a ^ reg_b;
                            next_flag_z = (temp_a == 8'h00);
                            next_flag_n = 1'b0;
                            next_flag_h = 1'b0;
                            next_flag_c = 1'b0;
                        end
                        // ... other XOR r ...

                        // OR B (0xB0) - 1 M-cycle
                        8'hB0: begin
                            temp_a      = reg_a | reg_b;
                            next_flag_z = (temp_a == 8'h00);
                            next_flag_n = 1'b0;
                            next_flag_h = 1'b0;
                            next_flag_c = 1'b0;
                        end
                        // ... other OR r ...

                        // CP B (Compare A with B) (0xB8) - 1 M-cycle
                        8'hB8: begin
                            alu_sub_res = {1'b0, reg_a} - {1'b0, reg_b};
                            alu_h_sub_res = (reg_a & 8'h0F) - (reg_b & 8'h0F);
                            // A is not modified
                            next_flag_z = (alu_sub_res[7:0] == 8'h00);
                            next_flag_n = 1'b1;
                            next_flag_h = alu_h_sub_res[4]; // Borrow from bit 4
                            next_flag_c = alu_sub_res[8]; // Borrow
                        end
                        // ... other CP r ...

                        // RET NZ (0xC0) - 2/5 M-cycles
                        // M1: Fetch opcode
                        // M2: Check condition. If !Z, proceed to POP. If Z, done (2 M-cycles total)
                        // M3: POP PCL from (SP)
                        // M4: POP PCH from (SP+1)
                        // M5: Internal, PC updated. (5 M-cycles total if condition met)
                        8'hC0: begin
                            if (!flag_z) begin // Condition met
                                next_state = S_POP_PCL; // Start POP sequence
                                addr_bus = reg_sp;
                                mem_rd_en_internal = 1'b1;
                                // temp_sp will be incremented by 2 later.
                            end else begin // Condition not met, 2 M-cycles total
                                // Already did 1 M-cycle for fetch, need 1 more "dummy" cycle.
                                next_state = S_EXECUTE_MULTI; // Dummy cycle
                            end
                        end
                        // ... other RET cc ...

                        // POP BC (0xC1) - 3 M-cycles
                        // M1: Fetch opcode
                        // M2: POP C from (SP) -> operand1
                        // M3: POP B from (SP+1) -> operand2, update BC, SP+=2
                        8'hC1: begin
                            next_state = S_POP_PCL; // Re-use POP sequence logic, operand1 for C
                            addr_bus = reg_sp;
                            mem_rd_en_internal = 1'b1;
                            // Later, temp_c = operand1, temp_b = operand2
                        end

                        // JP NZ, nn (0xC2) - 3/4 M-cycles
                        // M1: Fetch opcode
                        // M2: Fetch nn_low -> operand1
                        // M3: Fetch nn_high -> operand2. Check condition. If !Z, PC={op2,op1} (4 M-cycles)
                        //                                                If Z, do nothing (3 M-cycles)
                        8'hC2: begin
                            next_state = S_MEM_READ_OP1; // Fetch nn_low
                            addr_bus = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end
                        
                        // JP nn (0xC3) - 4 M-cycles
                        // M1: Fetch Opcode
                        // M2: Fetch nn_low -> operand1
                        // M3: Fetch nn_high -> operand2
                        // M4: PC = {operand2, operand1} (internal op)
                        8'hC3: begin
                            next_state         = S_MEM_READ_OP1; // Fetch low byte for jump address
                            addr_bus           = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end

                        // CALL NZ, nn (0xC4) - 3/6 M-cycles
                        // M1: Fetch opcode
                        // M2: Fetch nn_low -> operand1
                        // M3: Fetch nn_high -> operand2. Check condition.
                        //     If !Z: proceed to PUSH PC (6 M-cycles)
                        //     If Z: done (3 M-cycles)
                        // M4: PUSH PCH onto stack (SP-1)
                        // M5: PUSH PCL onto stack (SP-2)
                        // M6: PC = {operand2, operand1} (internal op)
                        8'hC4: begin
                            next_state = S_MEM_READ_OP1; // Fetch nn_low for CALL address
                            addr_bus = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end

                        // PUSH BC (0xC5) - 4 M-cycles
                        // M1: Fetch Opcode
                        // M2: Internal (SP--)
                        // M3: Write B to (SP)
                        // M4: Write C to (SP-1), SP--
                        8'hC5: begin
                            // This will push B then C. SP decreases.
                            next_state = S_EXECUTE_MULTI; // M2: Internal (SP decrement before first push)
                            // The push sequence itself (S_PUSH_PCH, S_PUSH_PCL) can be adapted
                        end

                        // ADD A, n (0xC6) - 2 M-cycles
                        8'hC6: begin
                            next_state         = S_MEM_READ_OP1; // Fetch n
                            addr_bus           = reg_pc;
                            mem_rd_en_internal = 1'b1;
                            // Actual ADD A, operand1 happens after read
                        end

                        // RET (0xC9) - 4 M-cycles
                        // M1: Fetch Opcode
                        // M2: POP PCL from (SP) -> operand1
                        // M3: POP PCH from (SP+1) -> operand2
                        // M4: PC = {operand2, operand1}, SP += 2
                        8'hC9: begin
                            next_state         = S_POP_PCL;
                            addr_bus           = reg_sp;
                            mem_rd_en_internal = 1'b1;
                        end

                        // CB Prefix (0xCB) - Triggers reading another byte for the actual instruction
                        8'hCB: begin
                            next_state         = S_MEM_READ_OP1; // Fetch CB opcode
                            addr_bus           = reg_pc;
                            mem_rd_en_internal = 1'b1;
                            // The actual CB instruction will be in operand1
                        end

                        // CALL nn (0xCD) - 6 M-cycles
                        8'hCD: begin
                            next_state = S_MEM_READ_OP1; // Fetch nn_low for CALL address
                            addr_bus = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end

                        // DI (Disable Interrupts) (0xF3) - 1 M-cycle
                        8'hF3: begin
                            temp_ime = 1'b0;
                            // Actual disable effect is delayed by one instruction in real HW
                            // For simplicity here, immediate effect.
                        end

                        // EI (Enable Interrupts) (0xFB) - 1 M-cycle
                        8'hFB: begin
                            temp_ime = 1'b1;
                            // Actual enable effect is delayed by one instruction in real HW
                            // For simplicity here, immediate effect.
                        end

                        // CP n (Compare A with n) (0xFE) - 2 M-cycles
                        8'hFE: begin
                            next_state         = S_MEM_READ_OP1; // Fetch n
                            addr_bus           = reg_pc;
                            mem_rd_en_internal = 1'b1;
                            // Actual CP A, operand1 happens after read
                        end

                        // HALT (0x76) - 1+ M-cycles
                        // Halts CPU until an interrupt occurs.
                        // If IME=0, it has weird behavior (HALT bug), not fully modeled here.
                        8'h76: begin
                            temp_halt = 1'b1;
                            // Stays in S_FETCH_OPCODE if no IRQs
                        end

                        default: begin
                            // Undefined opcode - could be treated as NOP or HALT, or error
                            // For now, treat as NOP.
                        end
                    endcase
                end // S_DECODE_EXEC

                S_MEM_READ_OP1: begin // Finished reading operand1 (e.g. n, or nn_low)
                    // operand1 is now valid (latched by clocked block)
                    // PC is now pointing to operand2 or next instruction
                    mem_rd_en_internal = 1'b0; // Done reading for this M-cycle

                    case (opcode) // What to do after fetching operand1
                        8'h01: begin // LD BC, nn (got C=operand1, now get B)
                            next_state         = S_MEM_READ_OP2;
                            addr_bus           = reg_pc; // PC already advanced
                            mem_rd_en_internal = 1'b1;
                        end
                        8'h06: begin // LD B, n (got n=operand1)
                            temp_b     = operand1;
                            next_state = S_IRQ_CHECK;
                        end
                        8'h08: begin // LD (nn), SP (got nn_low = operand1)
                            next_state = S_MEM_READ_OP2; // Fetch nn_high
                            addr_bus   = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end
                        8'h3E: begin // LD A, n (got n=operand1)
                            temp_a     = operand1;
                            next_state = S_IRQ_CHECK;
                        end
                        8'hC2: begin // JP NZ, nn (got nn_low = operand1)
                            next_state = S_MEM_READ_OP2;
                            addr_bus   = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end
                        8'hC3: begin // JP nn (got nn_low = operand1)
                            next_state         = S_MEM_READ_OP2;
                            addr_bus           = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end
                        8'hC4: begin // CALL NZ, nn (got nn_low = operand1)
                            next_state = S_MEM_READ_OP2;
                            addr_bus = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end
                        8'hC6: begin // ADD A, n (got n=operand1)
                            alu_add_res = {1'b0, reg_a} + {1'b0, operand1};
                            alu_h_add_res = (reg_a & 8'h0F) + (operand1 & 8'h0F);
                            temp_a      = alu_add_res[7:0];
                            next_flag_z = (temp_a == 8'h00);
                            next_flag_n = 1'b0;
                            next_flag_h = alu_h_add_res[4];
                            next_flag_c = alu_add_res[8];
                            next_state  = S_IRQ_CHECK;
                        end
                        8'hCB: begin // CB Prefix (got CB opcode = operand1)
                            // Now decode operand1 (the CB opcode)
                            // All CB opcodes are 2 M-cycles (fetch CB, fetch op, execute)
                            // or 4 M-cycles if (HL) is involved.
                            // Example: RLC B (0xCB 0x00)
                            case (operand1) // This is the CB opcode
                                8'h00: begin // RLC B
                                    next_flag_c = reg_b[7];
                                    temp_b      = {reg_b[6:0], reg_b[7]};
                                    next_flag_z = (temp_b == 8'h00);
                                    next_flag_n = 1'b0;
                                    next_flag_h = 1'b0;
                                end
                                // ... many more CB opcodes ...
                                default: ; // Unknown CB opcode
                            endcase
                            next_state = S_IRQ_CHECK;
                        end
                        8'hCD: begin // CALL nn (got nn_low = operand1)
                            next_state = S_MEM_READ_OP2;
                            addr_bus = reg_pc;
                            mem_rd_en_internal = 1'b1;
                        end
                        8'hFE: begin // CP n (got n=operand1)
                            alu_sub_res = {1'b0, reg_a} - {1'b0, operand1};
                            alu_h_sub_res = (reg_a & 8'h0F) - (operand1 & 8'h0F);
                            next_flag_z = (alu_sub_res[7:0] == 8'h00);
                            next_flag_n = 1'b1;
                            next_flag_h = alu_h_sub_res[4];
                            next_flag_c = alu_sub_res[8];
                            next_state  = S_IRQ_CHECK;
                        end
                        default: next_state = S_IRQ_CHECK; // Should not happen for valid opcodes
                    endcase
                end // S_MEM_READ_OP1

                S_MEM_READ_OP2: begin // Finished reading operand2 (e.g. nn_high)
                    // operand2 is now valid
                    mem_rd_en_internal = 1'b0;
                    case (opcode)
                        8'h01: begin // LD BC, nn (got C=operand1, B=operand2)
                            temp_c     = operand1;
                            temp_b     = operand2;
                            next_state = S_IRQ_CHECK;
                        end
                        8'h08: begin // LD (nn), SP (got nn_low=op1, nn_high=op2)
                            addr_temp = {operand2, operand1}; // Target address
                            // Now need to write SP low, then SP high
                            next_state = S_MEM_WRITE_VAL; // Write SP_low
                            addr_bus = addr_temp;
                            data_bus_out_internal = reg_sp[7:0]; // SP_low
                            mem_wr_en_internal = 1'b1;
                        end
                        8'hC2: begin // JP NZ, nn (got nn_low=op1, nn_high=op2)
                            if (!flag_z) begin // Condition met
                                temp_pc = {operand2, operand1};
                                next_state = S_EXECUTE_MULTI; // Extra M-cycle for conditional jump taken
                            end else begin // Condition not met
                                next_state = S_IRQ_CHECK; // PC already advanced past nn
                            end
                        end
                        8'hC3: begin // JP nn (got nn_low=operand1, nn_high=operand2)
                            temp_pc    = {operand2, operand1};
                            // JP takes 4 M-cycles. Fetch (1), Read op1 (1), Read op2 (1), Internal (1).
                            // We are at end of M3. Need one more.
                            next_state = S_EXECUTE_MULTI;
                        end
                        8'hC4: begin // CALL NZ, nn (got nn_low=op1, nn_high=op2)
                            addr_temp = {operand2, operand1}; // Store call address
                            if (!flag_z) begin // Condition met, proceed to PUSH PC
                                next_state = S_PUSH_PCH;
                                // SP is not decremented yet for first push item
                                addr_bus = reg_sp - 1; // PCH will be pushed here
                                data_bus_out_internal = reg_pc[15:8]; // Current PC (after nn) high byte
                                mem_wr_en_internal = 1'b1;
                            end else { // Condition not met
                                next_state = S_IRQ_CHECK; // PC already advanced past nn
                            }
                        end
                        8'hCD: begin // CALL nn (got nn_low=op1, nn_high=op2)
                            addr_temp = {operand2, operand1}; // Store call address
                            // Proceed to PUSH PC
                            next_state = S_PUSH_PCH;
                            addr_bus = reg_sp - 1; // PCH will be pushed here
                            data_bus_out_internal = reg_pc[15:8]; // Current PC (after nn) high byte
                            mem_wr_en_internal = 1'b1;
                        end
                        default: next_state = S_IRQ_CHECK;
                    endcase
                end // S_MEM_READ_OP2

                S_MEM_WRITE_VAL: begin // Finished writing a value to memory
                    mem_wr_en_internal = 1'b0;
                    case(opcode)
                        8'h02: begin // LD (BC), A - done
                            next_state = S_IRQ_CHECK;
                        end
                        8'h08: begin // LD (nn), SP - wrote SP_low to (nn)
                            // Now write SP_high to (nn+1)
                            // This opcode variant is tricky. Some docs say (nn) gets SP_low, (nn+1) gets SP_high
                            // We stored nn in addr_temp
                            next_state = S_EXECUTE_MULTI; // This will be the state to write SP_high
                            addr_bus = addr_temp + 1;
                            data_bus_out_internal = reg_sp[15:8]; // SP_high
                            mem_wr_en_internal = 1'b1;
                            // The actual S_EXECUTE_MULTI for 0x08 will just transition to S_IRQ_CHECK
                        end
                        default: next_state = S_IRQ_CHECK;
                    endcase
                end // S_MEM_WRITE_VAL

                S_MEM_READ_VAL: begin // Finished reading a value from memory into data_temp
                    mem_rd_en_internal = 1'b0;
                    // data_temp is now valid
                    case(opcode)
                        8'h0A: begin // LD A, (BC)
                            temp_a = data_temp;
                            next_state = S_IRQ_CHECK;
                        end
                        8'h7E: begin // LD A, (HL)
                            temp_a = data_temp;
                            next_state = S_IRQ_CHECK;
                        end
                        8'h86: begin // ADD A, (HL) - value from (HL) is in data_temp
                            alu_add_res = {1'b0, reg_a} + {1'b0, data_temp};
                            alu_h_add_res = (reg_a & 8'h0F) + (data_temp & 8'h0F);
                            temp_a      = alu_add_res[7:0];
                            next_flag_z = (temp_a == 8'h00);
                            next_flag_n = 1'b0;
                            next_flag_h = alu_h_add_res[4];
                            next_flag_c = alu_add_res[8];
                            next_state = S_IRQ_CHECK;
                        end
                        default: next_state = S_IRQ_CHECK;
                    endcase
                end // S_MEM_READ_VAL

                S_EXECUTE_MULTI: begin // Placeholder for multi-M-cycle instructions' internal ops
                    // Or for final step of some instructions.
                    case(opcode)
                        8'h03: next_state = S_IRQ_CHECK; // INC BC done
                        8'h08: next_state = S_IRQ_CHECK; // LD (nn), SP done writing SP_high
                        8'h09: next_state = S_IRQ_CHECK; // ADD HL, BC done
                        8'hC0: next_state = S_IRQ_CHECK; // RET NZ (condition false branch done)
                        8'hC2: next_state = S_IRQ_CHECK; // JP NZ, nn (condition true branch done)
                        8'hC3: next_state = S_IRQ_CHECK; // JP nn (final internal M-cycle done)
                        8'hC5: begin // PUSH BC - M2: internal SP decrement. Now M3: push B
                            temp_sp = reg_sp - 1; // Decrement for B
                            next_state = S_PUSH_PCH; // Re-use PUSH logic, PCH for B
                            addr_bus = temp_sp;
                            data_bus_out_internal = reg_b;
                            mem_wr_en_internal = 1'b1;
                            // S_PUSH_PCH will transition to S_PUSH_PCL for C
                        end
                        default: next_state = S_IRQ_CHECK;
                    endcase
                end // S_EXECUTE_MULTI

                S_PUSH_PCH: begin // Finished PUSHing PCH (or first byte of PUSH rr)
                    // SP was decremented in clocked block based on previous state
                    mem_wr_en_internal = 1'b0;
                    case (opcode)
                        8'hC4: begin // CALL NZ, nn (Pushed PC_High, now push PC_Low)
                            next_state = S_PUSH_PCL;
                            addr_bus = reg_sp - 1; // PCL will be pushed here (SP already dec'd for PCH)
                            data_bus_out_internal = reg_pc[7:0]; // Current PC (after nn) low byte
                            mem_wr_en_internal = 1'b1;
                            // After S_PUSH_PCL, PC will be set to addr_temp (call target)
                        end
                        8'hC5: begin // PUSH BC (Pushed B, now push C)
                            // operand1 will hold C. S_PUSH_PCL will use this.
                            // data_temp used to hold original value of B temporarily for the PUSH.
                            // Let's make it explicit:
                            next_state = S_PUSH_PCL;
                            addr_bus = reg_sp - 1; // C will be pushed here (SP already dec'd for B)
                            data_bus_out_internal = reg_c;
                            mem_wr_en_internal = 1'b1;
                        end
                        8'hCD: begin // CALL nn (Pushed PC_High, now push PC_Low)
                            next_state = S_PUSH_PCL;
                            addr_bus = reg_sp - 1;
                            data_bus_out_internal = reg_pc[7:0];
                            mem_wr_en_internal = 1'b1;
                        end
                        default: next_state = S_IRQ_CHECK; // Should not happen
                    endcase
                end

                S_PUSH_PCL: begin // Finished PUSHing PCL (or second byte of PUSH rr)
                    // SP was decremented
                    mem_wr_en_internal = 1'b0;
                     case (opcode)
                        8'hC4: begin // CALL NZ, nn (Finished PUSH PC)
                            temp_pc = addr_temp; // Jump to call address
                            next_state = S_EXECUTE_MULTI; // Extra M-cycle for CALL taken
                        end
                        8'hC5: begin // PUSH BC (Finished PUSH C)
                            next_state = S_IRQ_CHECK;
                        end
                        8'hCD: begin // CALL nn (Finished PUSH PC)
                            temp_pc = addr_temp; // Jump to call address
                            next_state = S_EXECUTE_MULTI; // Extra M-cycle for CALL taken
                        end
                        default: next_state = S_IRQ_CHECK; // Should not happen
                    endcase
                end

                S_POP_PCL: begin // Finished POPing PCL (or first byte of POP rr) -> into operand1
                    // SP will be incremented by clocked logic
                    temp_sp = reg_sp + 1;
                    mem_rd_en_internal = 1'b0;
                    // Now POP PCH (or second byte of POP rr)
                    next_state = S_POP_PCH;
                    addr_bus = temp_sp; // SP has been inc'd
                    mem_rd_en_internal = 1'b1;
                end

                S_POP_PCH: begin // Finished POPing PCH (or second byte of POP rr) -> into operand2
                    // SP will be incremented by clocked logic
                    temp_sp = reg_sp + 1;
                    mem_rd_en_internal = 1'b0;
                    // Now update registers based on opcode and {operand2, operand1}
                    case(opcode)
                        8'hC0: begin // RET NZ (condition was true)
                            // PC is updated by clocked logic from operand1, operand2
                            next_state = S_EXECUTE_MULTI; // Extra M-cycle for RET taken
                        end
                        8'hC1: begin // POP BC
                            temp_c = operand1; // PCL was C
                            temp_b = operand2; // PCH was B
                            next_state = S_IRQ_CHECK;
                        end
                        8'hC9: begin // RET
                            // PC is updated by clocked logic from operand1, operand2
                            next_state = S_EXECUTE_MULTI; // Extra M-cycle for RET taken
                        end
                        default: next_state = S_IRQ_CHECK;
                    endcase
                end

                S_IRQ_CHECK: begin
                    if (ime_flag && pending_irq && !halt_mode) begin // HALT mode exits on IRQ, then handles it
                        // Interrupt sequence: 5 M-cycles
                        // M1 (this one): Internal, IME is reset (actually after M2 in HW)
                        // M2: Push PCH onto stack (SP-1)
                        // M3: Push PCL onto stack (SP-2)
                        // M4: Dummy cycle
                        // M5: Jump to interrupt vector
                        next_state = S_IRQ_SEQ_1; // Start IRQ sequence
                        // No memory access in this first M-cycle of IRQ handling
                        addr_bus = reg_pc; // Keep bus stable
                    end else begin
                        next_state = S_FETCH_OPCODE; // Fetch next instruction
                    end
                end

                S_IRQ_SEQ_1: begin // M-cycle 2 of IRQ: Push PCH
                    // SP was decremented by clocked block
                    addr_bus = reg_sp; // Current SP (after first dec)
                    data_bus_out_internal = reg_pc[15:8]; // PCH
                    mem_wr_en_internal = 1'b1;
                    next_state = S_IRQ_SEQ_2;
                end

                S_IRQ_SEQ_2: begin // M-cycle 3 of IRQ: Push PCL
                    // SP was decremented by clocked block
                    // IME reset, IF flag cleared by clocked block
                    addr_bus = reg_sp; // Current SP (after second dec)
                    data_bus_out_internal = reg_pc[7:0]; // PCL
                    mem_wr_en_internal = 1'b1;
                    next_state = S_IRQ_SEQ_3;
                end
                S_IRQ_SEQ_3: begin // M-cycle 4 of IRQ: Dummy cycle
                    // PC will be set to ISR vector in next state based on IF/IE
                    // No memory access
                    addr_bus = reg_pc; // Keep bus stable (points to old PC)
                    next_state = S_IRQ_SEQ_4;
                end
                S_IRQ_SEQ_4: begin // M-cycle 5 of IRQ: Actual jump
                    // PC set by clocked block
                    // No memory access, this cycle is internal for PC update
                    addr_bus = reg_pc; // This should be the new PC (ISR vector)
                    next_state = S_FETCH_OPCODE; // Start fetching from ISR
                end

                default: begin
                    next_state = S_FETCH_OPCODE; // Should not happen
                end
            endcase
        end // if (m_cycle_done)

        // Latch next register values if m_cycle_done. This is tricky.
        // The actual latching occurs in the clocked `always` block.
        // This `always_comb` block *calculates* what those next values should be.
        // The `reg_a <= temp_a` etc. in the clocked block handles the update.
        // What we need here is to ensure `temp_a` etc. reflect the *outcome* of the instruction
        // that *just completed* if `m_cycle_done` is true and we are in S_DECODE_EXEC or S_EXECUTE_MULTI.
        if (m_cycle_done && (current_state == S_DECODE_EXEC || current_state == S_MEM_READ_OP1 || current_state == S_MEM_READ_OP2 || current_state == S_MEM_READ_VAL || current_state == S_EXECUTE_MULTI)) begin
            // This block in always_comb is essentially calculating the values that will be
            // clocked into the registers at the posedge clk when m_cycle_done is true.
            // The assignments to temp_x variables within the case(opcode) should be correct.
        end

        // Update actual register values (combinatorially, to be latched by ff)
        // This is tricky. The clocked block does reg_x <= temp_x_calculated_here.
        // So the temp_x should reflect the values *after* the instruction.
        // And the F register from individual flags.
        // The clocked always block then does:
        // reg_a <= temp_a; reg_f <= {next_flag_z, next_flag_n, next_flag_h, next_flag_c, 4'b0000}; etc.

    end // always_comb

    // This drives the actual register updates at the end of relevant M-cycles.
    // It ensures that temp_x values calculated in always_comb are latched.
    always @(posedge clk) begin
        if (m_cycle_done && (current_state == S_DECODE_EXEC || current_state == S_MEM_READ_OP1 || current_state == S_MEM_READ_OP2 || current_state == S_MEM_READ_VAL || current_state == S_EXECUTE_MULTI || current_state == S_PUSH_PCH || current_state == S_PUSH_PCL || current_state == S_POP_PCL || current_state == S_POP_PCH)) begin
            // Values calculated in the 'always_comb' by 'temp_x = ...'
            // are now latched into the actual registers.
            // This uses the 'temp_x' values that were set in the 'always_comb' block.
            // This is a common pattern: calculate next state/values combinatorially, then register them.
            // The always_comb above sets 'temp_a', 'next_flag_z' etc.
            
            // This is a bit of a simplification. The next_state logic itself should determine
            // when the final write to registers happens based on the instruction's M-cycles.
            // The temp_x variables in always_comb are the "next values" for the registers.
            // The clocked block should then do:
            // reg_a <= calculated_next_reg_a;
            // reg_f <= calculated_next_reg_f; ...
            
            // Let's refine: The always_comb calculates the next values for *all* registers.
            // The clocked block *always* assigns them if m_cycle_done.
            // The always_comb must ensure that if an instruction doesn't change a reg, its temp_x is set to current value.
            // (This is already done by `temp_a = reg_a;` etc. at the start of always_comb)
            
            reg_a <= temp_a;
            reg_b <= temp_b;
            reg_c <= temp_c;
            reg_d <= temp_d;
            reg_e <= temp_e;
            reg_h <= temp_h;
            reg_l <= temp_l;
            reg_f <= {next_flag_z, next_flag_n, next_flag_h, next_flag_c, 4'b0000};
            
            // PC and SP updates are more complex and often handled by specific states
            // or directly in the main clocked block's state transitions.
            // However, for jumps/calls/rets, temp_pc is set in always_comb.
            if (opcode == 8'hC3 || opcode == 8'hC2 || opcode == 8'hC4 || opcode == 8'hCD ||
                opcode == 8'hC9 || opcode == 8'hC0) // JP, CALL, RET type instructions
            begin
                 if (next_state == S_EXECUTE_MULTI || next_state == S_IRQ_CHECK) // If jump/call/ret taken
                    reg_pc <= temp_pc;
            end

            // SP updates for PUSH/POP
            if (current_state == S_PUSH_PCH || current_state == S_PUSH_PCL ||
                current_state == S_POP_PCL  || current_state == S_POP_PCH ||
                (current_state == S_EXECUTE_MULTI && opcode == 8'hC5) ) // PUSH BC M2
            begin
                 reg_sp <= temp_sp;
            end
            
            ime_flag <= temp_ime;
            halt_mode <= temp_halt;
        end
    end


//------------------------------------------------------------------------------
// Assertions (Example)
//------------------------------------------------------------------------------
`ifdef FORMAL_VERIFICATION
    // Example: PC should not go beyond addressable memory (simplistic)
    // assert property (@(posedge clk) (reg_pc < 16'hFFFE)); // SP usually at FFFE

    // Example: SP should generally stay within RAM limits during normal ops
    // assert property (@(posedge clk) (reg_sp >= 16'hC000 && reg_sp <= 16'hFFFE));

    // Example: Read and Write enable should be mutually exclusive
    assert property (@(posedge clk) !(mem_rd_en && mem_wr_en));
`elsif SIMULATION
    // Simulation specific assertions
    always @(posedge clk) begin
        if (rst_n) begin
            // if (reg_pc >= 16'hE000 && reg_pc < 16'hFE00) begin // ECHO RAM, not usually PC target
            //     $display("%t: Warning: PC in ECHO RAM area: %h", $time, reg_pc);
            // end
            if (mem_rd_en && mem_wr_en) begin
                $error("%t: FATAL: Simultaneous read and write enabled!", $time);
            end
        end
    end
`endif


endmodule