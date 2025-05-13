module memory_interface (
    input wire clk,
    input wire rst_n,
    input wire [15:0] addr,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    input wire rd_n,
    input wire wr_n,
    output reg wait_n,
    
    // Memory region chip select
    output reg rom_cs_n,
    output reg ram_cs_n,
    output reg vram_cs_n,
    output reg oam_cs_n,
    output reg io_cs_n,
    output reg hram_cs_n,
    // External IO ports
    input  wire [7:0] io_in,   // e.g. switches
    output reg  [7:0] io_out   // e.g. LEDs
);

    // Address range definitions
    localparam ROM_START = 16'h0000;
    localparam ROM_END   = 16'h7FFF;
    localparam VRAM_START = 16'h8000;
    localparam VRAM_END   = 16'h9FFF;
    localparam RAM_START = 16'hA000;
    localparam RAM_END   = 16'hBFFF;
    localparam OAM_START = 16'hFE00;
    localparam OAM_END   = 16'hFE9F;
    localparam IO_START  = 16'hFF00;
    localparam IO_END    = 16'hFF7F;
    localparam HRAM_START = 16'hFF80;
    localparam HRAM_END   = 16'hFFFF;

    // Simple memory arrays for simulation/demo
    reg [7:0] rom [0:32767];   // 32KB ROM
    reg [7:0] vram [0:8191];   // 8KB VRAM
    reg [7:0] ram [0:8191];    // 8KB RAM
    reg [7:0] oam [0:159];     // 160B OAM
    reg [7:0] io [0:127];      // 128B IO
    reg [7:0] hram [0:127];    // 128B HRAM

    // ROM initialization from external file
    initial begin
        $readmemh("rom.hex", rom); // Load ROM content from hex file
    end

    // Memory region select logic
    always @(*) begin
        // Default: all chip select inactive, wait_n inactive
        rom_cs_n  = 1'b1;
        ram_cs_n  = 1'b1;
        vram_cs_n = 1'b1;
        oam_cs_n  = 1'b1;
        io_cs_n   = 1'b1;
        hram_cs_n = 1'b1;
        wait_n    = 1'b1;

        if (addr >= ROM_START && addr <= ROM_END) begin
            rom_cs_n = 1'b0;
            wait_n = 1'b0;  // ROM access may need wait
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

    // Data read/write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 8'h00;
            io_out   <= 8'h00;
            // Optionally clear RAM/VRAM/HRAM here
        end else begin
            if (!rd_n) begin
                // Read operation
                if (!rom_cs_n)
                    data_out <= rom[addr];
                else if (!vram_cs_n)
                    data_out <= vram[addr - VRAM_START];
                else if (!ram_cs_n)
                    data_out <= ram[addr - RAM_START];
                else if (!oam_cs_n)
                    data_out <= oam[addr - OAM_START];
                else if (!io_cs_n) begin
                    if (addr == 16'hFF00)
                        data_out <= io_in; // Read external input
                    else
                        data_out <= io[addr - IO_START];
                end else if (!hram_cs_n)
                    data_out <= hram[addr - HRAM_START];
                else
                    data_out <= 8'hFF; // Default value if address is invalid
            end
            if (!wr_n) begin
                // Write operation
                if (!vram_cs_n)
                    vram[addr - VRAM_START] <= data_in;
                else if (!ram_cs_n)
                    ram[addr - RAM_START] <= data_in;
                else if (!oam_cs_n)
                    oam[addr - OAM_START] <= data_in;
                else if (!io_cs_n) begin
                    if (addr == 16'hFF01)
                        io_out <= data_in; // Write to external output
                    else
                        io[addr - IO_START] <= data_in;
                end else if (!hram_cs_n)
                    hram[addr - HRAM_START] <= data_in;
                // ROM is read-only, do not write
            end
        end
    end

endmodule 