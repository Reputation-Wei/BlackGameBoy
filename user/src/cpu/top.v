module top (
    input wire clk,           // System clock
    input wire [0:0]btn,         // Active-low reset (button)
    output wire [7:0] led,    // LEDs for debug
    input wire [7:0] sw,      // Switches for test input
    output wire [3:0] seg_an, // 7-segment display anode
    output wire [7:0] seg_cat // 7-segment display cathode
);
    wire rst_n;
    assign rst_n = btn[0];
    // Internal wires
    wire [7:0] cpu_data_out;
    wire [15:0] cpu_addr;
    wire cpu_rd_n, cpu_wr_n, cpu_m1_n;
    wire [7:0] reg_data_out;
    wire [7:0] alu_result;
    wire [3:0] alu_op;
    wire [2:0] reg_src, reg_dst;
    wire [1:0] reg_pair;
    wire imm_en;
    wire [1:0] mem_op, branch_type, stack_op;
    wire [2:0] interrupt_type;
    wire cpu_clk;
    //clock divid
    clk_div clk_div_inst(
        .clk(clk),
        .rst_n(rst_n),
        .cpu_clk(cpu_clk)
    );  

    // Instantiate CPU
    gb_cpu cpu (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .data_in(reg_data_out), // Connect register output to CPU data input
        .data_out(cpu_data_out),
        .addr(cpu_addr),
        .rd_n(cpu_rd_n),
        .wr_n(cpu_wr_n),
        .int_n(1'b1),           // No interrupt for now
        .m1_n(cpu_m1_n)
    );

    // Instantiate Registers
    registers regs (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .reg_addr(reg_src),     // Register address from decoder
        .data_in(cpu_data_out), // Data from CPU
        .write_en(cpu_wr_n == 1'b0), // Write enable when wr_n is low
        .data_out(reg_data_out),
        .reg_pair(reg_pair),
        .pair_data_in(16'b0),   // Not used in this example
        .pair_write_en(1'b0),   // Not used in this example
        .pair_data_out()        // Not used in this example
    );

    // Instantiate ALU
    alu alu_inst (
        .a(reg_data_out),       // Operand A from register
        .b(sw),                 // Operand B from switches for test
        .op(alu_op),            // ALU operation from decoder
        .carry_in(1'b0),        // No carry for now
        .result(alu_result),
        .carry_out(),           // Not used in this example
        .half_carry_out(),      // Not used in this example
        .zero_out(),            // Not used in this example
        .subtract_out()         // Not used in this example
    );

    // Instantiate Decoder
    decoder decoder_inst (
        .opcode(cpu_data_out),  // Use CPU data_out as opcode for test
        .alu_op(alu_op),
        .reg_src(reg_src),
        .reg_dst(reg_dst),
        .reg_pair(reg_pair),
        .imm_en(imm_en),
        .mem_op(mem_op),
        .branch_type(branch_type),
        .stack_op(stack_op),
        .interrupt_type(interrupt_type)
    );
    // Instantiate memory interface
    memory_interface mem (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .addr(cpu_addr),
        .data_in(cpu_data_out),
        .data_out(cpu_data_in),
        .rd_n(cpu_rd_n),
        .wr_n(cpu_wr_n),
        .wait_n(),
        .rom_cs_n(), .ram_cs_n(), .vram_cs_n(), .oam_cs_n(), .io_cs_n(), .hram_cs_n(),
        .io_in(sw),
        .io_out(led)
    );

    // Debug: Show current instruction on LEDs
    assign led = cpu_data_out;

    // TODO: Add 7-segment display logic to show PC or other values
    //wire [15:0] pc;
    //assign pc = cpu.pc;       //Programm counter

    ssegcontrol seg(
    .B(cpu_addr),//Binary code
    .clk(clk),
    .seg_cat(seg_cat),//segment
    .seg_an(seg_an)
);

endmodule