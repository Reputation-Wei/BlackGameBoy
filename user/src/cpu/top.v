module top (
    input wire clk,           // System clock
    input wire rst_n,         // Reset (button)
    output wire [7:0] led,    // LEDs for debug
    input wire [7:0] sw,      // Switches for test input
    output wire [3:0] seg_an, // 7-segment anode
    output wire [7:0] seg_cat // 7-segment cathode
);

    // Internal wires for CPU <-> Memory interface
    wire [7:0] cpu_data_out;
    wire [7:0] cpu_data_in;
    wire [15:0] cpu_addr;
    wire cpu_rd_n, cpu_wr_n, cpu_m1_n;

    // Instantiate CPU
    gb_cpu cpu (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(cpu_data_in),   // Connect to memory interface
        .data_out(cpu_data_out), // Connect to memory interface
        .addr(cpu_addr),         // Connect to memory interface
        .rd_n(cpu_rd_n),         // Connect to memory interface
        .wr_n(cpu_wr_n),         // Connect to memory interface
        .int_n(1'b1),            // No interrupt for now
        .m1_n(cpu_m1_n)
    );

    // Instantiate memory interface
    memory_interface mem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(cpu_addr),
        .data_in(cpu_data_out),
        .data_out(cpu_data_in),
        .rd_n(cpu_rd_n),
        .wr_n(cpu_wr_n),
        .wait_n(),         // Not used for now
        .rom_cs_n(), .ram_cs_n(), .vram_cs_n(), .oam_cs_n(), .io_cs_n(), .hram_cs_n(),
        .io_in(sw),        // Map switches to IO input
        .io_out(led)       // Map LEDs to IO output
    );

    // 使用LED显示CPU状态
    assign led = cpu.ir;      // 显示当前指令

    // 七段数码管显示PC值
    // 这里需要添加七段数码管显示逻辑

endmodule