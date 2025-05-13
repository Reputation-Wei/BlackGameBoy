module tb_gb_cpu;
    reg clk;
    reg rst_n;
    reg [7:0] data_in;
    wire [7:0] data_out;
    wire [15:0] addr;
    wire rd_n;
    wire wr_n;
    reg int_n;
    wire m1_n;

    // 实例化CPU
    gb_cpu cpu (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out),
        .addr(addr),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .int_n(int_n),
        .m1_n(m1_n)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz时钟
    end

    // 测试用例
    initial begin
        // 初始化
        rst_n = 0;
        data_in = 8'h00;
        int_n = 1;
        
        // 复位释放
        #100;
        rst_n = 1;
        
        // 测试用例1：基本加载指令
        test_ld_instructions();
        
        // 测试用例2：算术运算
        test_arithmetic_instructions();
        
        // 测试用例3：逻辑运算
        test_logical_instructions();
        
        // 测试用例4：移位操作
        test_shift_instructions();
        
        // 测试用例5：跳转指令
        test_jump_instructions();
        
        // 测试用例6：中断处理
        test_interrupt_handling();
        
        #1000;
        $finish;
    end

    // 测试加载指令
    task test_ld_instructions;
        begin
            // LD A,n
            #20;
            data_in = 8'h3E;  // LD A,n
            #20;
            data_in = 8'h42;  // n = 0x42
            
            // LD B,A
            #20;
            data_in = 8'h47;  // LD B,A
            
            // LD (HL),A
            #20;
            data_in = 8'h77;  // LD (HL),A
        end
    endtask

    // 测试算术指令
    task test_arithmetic_instructions;
        begin
            // ADD A,B
            #20;
            data_in = 8'h80;  // ADD A,B
            
            // SUB A,B
            #20;
            data_in = 8'h90;  // SUB A,B
            
            // INC A
            #20;
            data_in = 8'h3C;  // INC A
            
            // DEC A
            #20;
            data_in = 8'h3D;  // DEC A
        end
    endtask

    // 测试逻辑指令
    task test_logical_instructions;
        begin
            // AND B
            #20;
            data_in = 8'hA0;  // AND B
            
            // OR B
            #20;
            data_in = 8'hB0;  // OR B
            
            // XOR B
            #20;
            data_in = 8'hA8;  // XOR B
        end
    endtask

    // 测试移位指令
    task test_shift_instructions;
        begin
            // RLCA
            #20;
            data_in = 8'h07;  // RLCA
            
            // RRCA
            #20;
            data_in = 8'h0F;  // RRCA
            
            // RLA
            #20;
            data_in = 8'h17;  // RLA
            
            // RRA
            #20;
            data_in = 8'h1F;  // RRA
        end
    endtask

    // 测试跳转指令
    task test_jump_instructions;
        begin
            // JP nn
            #20;
            data_in = 8'hC3;  // JP nn
            #20;
            data_in = 8'h00;  // nn low
            #20;
            data_in = 8'h10;  // nn high
            
            // JR n
            #20;
            data_in = 8'h18;  // JR n
            #20;
            data_in = 8'h05;  // n = 5
        end
    endtask

    // 测试中断处理
    task test_interrupt_handling;
        begin
            // 触发VBlank中断
            #20;
            int_n = 0;
            #20;
            int_n = 1;
            
            // 等待中断处理
            #100;
        end
    endtask

    // 监控
    initial begin
        $monitor("Time=%t rst_n=%b addr=%h data_in=%h data_out=%h rd_n=%b wr_n=%b int_n=%b",
                 $time, rst_n, addr, data_in, data_out, rd_n, wr_n, int_n);
    end

endmodule
