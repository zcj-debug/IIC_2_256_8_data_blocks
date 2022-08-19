/*========================================*\
  filename        : display.v
  description     : 滚动显示输入的数据
  up file         : 
  reversion       : 
      v1.0 : 2022-7-27 18:49:34
  author          : 张某某
\*========================================*/

module display #(parameter  MS_1= 16'd50000)(
    input                                   clk                 ,   // 50MHz
    input                                   rst_n               ,   // 复位信号
    input               [ 7:0]              data                ,
    output      reg     [ 5:0]              SEL                 ,   // SEL信号
    output      reg     [ 7:0]              DIG                     // DIG信号
);

// 信号定义
    reg                 [15:0]              cnt_flicker         ;   // 计数1ms
    wire                                    SEL_change          ;   // cnt_flicker计满使能信号
    reg                                     show_wei            ; 
    reg                 [ 3:0]              tmp_data            ;   // 当前DIG的值
    
// 逻辑描述
    // 闪烁频率计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_flicker <= 'd0;
        end
        else if (SEL_change) begin
            cnt_flicker <= 'd0;
        end
        else begin
            cnt_flicker <= cnt_flicker + 'd1; 
        end
    end
    assign SEL_change = cnt_flicker >= MS_1 - 'd1 ? 1'b1 : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            show_wei <= 'd0;
        end
        else if (SEL_change) begin
            show_wei <= ~show_wei;
        end
        else begin
            show_wei <= show_wei;
        end
    end

    // SEL信号输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SEL <= 6'b011_111;
        end
        else if (show_wei) begin
            SEL <= 6'b011_111;
        end
        else begin
            SEL <= 6'b101_111;
        end
    end

    // tmp_data当前SEL位选所对应的DIG十进制值
    always @(*) begin
        case (SEL)
            6'b011_111 : tmp_data = data[3:0];
            6'b101_111 : tmp_data = data[7:4];
            default: tmp_data = 'd0;
        endcase
    end

    // DIG输出各数字对应的二进制
    always @(*) begin
        case (tmp_data)
            4'd0 : DIG = 8'b1100_0000;
            4'd1 : DIG = 8'b1111_1001;
            4'd2 : DIG = 8'b1010_0100;
            4'd3 : DIG = 8'b1011_0000;
            4'd4 : DIG = 8'b1001_1001;
            4'd5 : DIG = 8'b1001_0010;
            4'd6 : DIG = 8'b1000_0010;
            4'd7 : DIG = 8'b1111_1000;
            4'd8 : DIG = 8'b1000_0000;
            4'd9 : DIG = 8'b1001_0000;
            4'd10: DIG = 8'b1000_1000;
            4'd11: DIG = 8'b1000_0011;
            4'd12: DIG = 8'b1100_0110;
            4'd13: DIG = 8'b1010_0001;
            4'd14: DIG = 8'b1000_0110;
            4'd15: DIG = 8'b1000_1110;
        endcase
    end

endmodule
