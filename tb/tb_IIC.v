/*========================================*\
    filename        : tb_IIC.v
    description     : 对IIC.v文件进行仿真
    up file         : 
    reversion       : 
        v1.0 : 2022-8-16 14:35:00
    author          : 张某某
\*========================================*/

`timescale 1ns/1ns

module tb_IIC;

// Parameter definition
    parameter       CYC_CLK             = 20            ;
    parameter       SCL_HIGH_HOUD       = 1100          ,
                    SCL_LOW_HOUD        = 1400          ;
    parameter       SAMPLE_TIME         = 800 / CYC_CLK ,
                    CHANGE_TIME         = 200 / CYC_CLK ;

// Drive signal
    reg                                 tb_clk          ;
    reg                                 tb_rst_n        ;
    reg                                 tb_SCL          ;
    reg                                 tb_SDA_in       ;

// Observation signal
    wire                                tb_SDA_out      ;
    wire                                tb_SDA_oe       ;

// Module calls
    IIC    #(.S_1(26'd100))                 U_IIC(
        /*input      */     .clk            (tb_clk     ),
        /*input      */     .rst_n          (tb_rst_n   ),
        /*input      */     .SCL            (tb_SCL     ),
        /*input      */     .SDA_in         (tb_SDA_in  ),
        /*output  reg*/     .SDA_out        (tb_SDA_out ),
        /*output  reg*/     .SDA_oe         (tb_SDA_oe  )
    );

// System initialization
    initial begin
        tb_clk = 1'b0;
        tb_rst_n = 1'b0;
        #(CYC_CLK) tb_rst_n = 1'b1;
    end
    always #(CYC_CLK >> 1) tb_clk = ~tb_clk;

    // SCL时钟信号
    initial begin
        tb_SCL = 1'b1;
        repeat(500) begin
            tb_SCL = 1'b1;
            #(SCL_HIGH_HOUD);
            tb_SCL = 1'b0;
            #(SCL_LOW_HOUD);
        end
    end

    // tb_SDA_in数据输入
    integer rand_num;
    initial begin
        tb_SDA_in = 1'b1;

        /************************
            写数据
        ************************/
        start_sig; // start开始

        send_one_byte(8'hA0); // 发送写控制

        send_one_byte(8'h23); // 发送地址字节
        
        repeat(8) begin // 发送n个数据字节
            rand_num = {$random} % 255;
            send_one_byte(rand_num);
        end

        stop_sig; // stop结束
        
        #(20000);

        /************************
            读数据
        ************************/
        start_sig; // start开始

        send_one_byte(8'ha0); // 写控制
        
        send_one_byte(8'h25); // 发送地址字节

        start_sig; // start开始

        send_one_byte(8'hA1); // 发送读控制
        
        repeat(4) begin // 读取n个数据字节
            receive_one_byte(0);
        end
        receive_one_byte(1);

        stop_sig;

        #(20000);

        $stop;

    end

    // start开始信号
    task start_sig;
        begin
            @(U_IIC.SCL_nedge);
            #(CHANGE_TIME * 20);
            tb_SDA_in = 1'b1;
            @(U_IIC.SCL_podge)
            #(600);
            tb_SDA_in = 1'b0;
        end
    endtask

    // stop停止信号
    task stop_sig;
        begin
            @(U_IIC.cnt_SCL_low == CHANGE_TIME);
            tb_SDA_in = 1'b0;
            #(10); 
            @(U_IIC.SCL_podge);
            #(600);
            tb_SDA_in = 1'b1;
        end
    endtask

    // 发送1byte数据
    integer cnt_bit;
    task send_one_byte;
        input           [ 7:0]              data_in;
        begin
            cnt_bit = 0;
            repeat(8) begin
                @(U_IIC.cnt_SCL_low == CHANGE_TIME);
                tb_SDA_in = data_in[7 - cnt_bit];
                #(100);
                cnt_bit = cnt_bit + 1;
            end
            @(U_IIC.cnt_SCL_low == CHANGE_TIME);
            tb_SDA_in = 1'b0;
            #(100);
        end
    endtask

    // 接收1byte数据
    task receive_one_byte;
        input                   continue_receive;
        begin
            cnt_bit = 0;
            repeat(8) begin
                @(U_IIC.cnt_SCL_low == CHANGE_TIME);
                tb_SDA_in = 'd0;
                #(100);
                cnt_bit = cnt_bit + 1;
            end
            @(U_IIC.cnt_SCL_low == CHANGE_TIME);
            tb_SDA_in = continue_receive;
            #(100);
        end
    endtask

endmodule
