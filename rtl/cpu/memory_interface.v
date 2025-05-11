module memory_interface (
    input wire clk,
    input wire rst_n,
    input wire [15:0] addr,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    input wire rd_n,
    input wire wr_n,
    output reg wait_n,
    
    // 内存区域选择
    output reg rom_cs_n,
    output reg ram_cs_n,
    output reg vram_cs_n,
    output reg oam_cs_n,
    output reg io_cs_n,
    output reg hram_cs_n
);

    // 内存区域地址范围
    localparam ROM_START = 16'h0000;
    localparam ROM_END = 16'h7FFF;
    localparam VRAM_START = 16'h8000;
    localparam VRAM_END = 16'h9FFF;
    localparam RAM_START = 16'hA000;
    localparam RAM_END = 16'hBFFF;
    localparam OAM_START = 16'hFE00;
    localparam OAM_END = 16'hFE9F;
    localparam IO_START = 16'hFF00;
    localparam IO_END = 16'hFF7F;
    localparam HRAM_START = 16'hFF80;
    localparam HRAM_END = 16'hFFFF;

    // 内存区域选择逻辑
    always @(*) begin
        // 默认值
        rom_cs_n = 1'b1;
        ram_cs_n = 1'b1;
        vram_cs_n = 1'b1;
        oam_cs_n = 1'b1;
        io_cs_n = 1'b1;
        hram_cs_n = 1'b1;
        wait_n = 1'b1;

        if (addr >= ROM_START && addr <= ROM_END) begin
            rom_cs_n = 1'b0;
            wait_n = 1'b0;  // ROM访问需要等待
        end else if (addr >= VRAM_START && addr <= VRAM_END) begin
            vram_cs_n = 1'b0;
        end else if (addr >= RAM_START && addr <= RAM_END) begin
            ram_cs_n = 1'b0;
        end else if (addr >= OAM_START && addr <= OAM_END) begin
            oam_cs_n = 1'b0;
        end else if (addr >= IO_START && addr <= IO_END) begin
            io_cs_n = 1'b0;
        end else if (addr >= HRAM_START && addr <= HRAM_END) begin
            hram_cs_n = 1'b0;
        end
    end

    // 数据输出控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 8'h00;
        end else if (!rd_n) begin
            // 根据选中的内存区域输出数据
            if (!rom_cs_n) begin
                // ROM数据读取
            end else if (!vram_cs_n) begin
                // VRAM数据读取
            end else if (!ram_cs_n) begin
                // RAM数据读取
            end else if (!oam_cs_n) begin
                // OAM数据读取
            end else if (!io_cs_n) begin
                // IO数据读取
            end else if (!hram_cs_n) begin
                // HRAM数据读取
            end
        end
    end

endmodule 