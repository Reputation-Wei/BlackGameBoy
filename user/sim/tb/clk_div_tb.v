`timescale 1ns/1ps

module clk_div_tb();
    // 定义信号
    reg clk;
    reg rst_n;
    wire cpu_clk;

    // 实例化被测模块
    clk_div u_clk_div(
        .clk(clk),
        .rst_n(rst_n),
        .cpu_clk(cpu_clk)
    );

    // 生成时钟信号
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz时钟，周期10ns
    end

    // 测试激励
    initial begin
        // 初始化VCD文件
        $dumpfile("clk_div.vcd");
        $dumpvars(0, clk_div_tb);
        
        // 初始化
        rst_n = 0;
        #100;
        
        // 释放复位
        rst_n = 1;
        
        // 等待足够长的时间观察分频效果
        #10000;
        
        // 再次复位测试
        rst_n = 0;
        #100;
        rst_n = 1;
        
        // 继续观察一段时间
        #10000;
        
        // 结束仿真
        $finish;
    end

    // 监控输出
    initial begin
        $monitor("Time=%0t rst_n=%b cpu_clk=%b", $time, rst_n, cpu_clk);
    end

endmodule