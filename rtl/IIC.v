/*========================================*\
    filename        : IIC.v
    description     : IIC模块
    up file         : IIC_slot_top.v
    reversion       : 
        v1.0 : 2022-8-16 13:50:19
    author          : 张宸君
\*========================================*/

module IIC (
    input                               clk                         ,
    input                               rst_n                       ,
    input                               SCL                         ,
    input                               SDA_in                      ,

    output  reg                         SDA_out                     ,
    output  reg                         SDA_oe                      ,
    output  reg     [ 7:0]              data_out
);

// Parameter definition
    parameter       CYC_CLK         =   20                          ;
    parameter       S_1             =   26'd50_000_000              ;

    parameter       SCL_HIGH_HOUD   =   1000 / CYC_CLK              ,
                    SCL_LOW_HOUD    =   1400 / CYC_CLK              ,
                    SAMPLE_TIME     =   800  / CYC_CLK              ,
                    CHANGE_TIME     =   200  / CYC_CLK              ;

    parameter       IDLE            =   7'b000_0001                 ,
                    START           =   7'b000_0010                 ,
                    CTRL_BYTE       =   7'b000_0100                 ,
                    ADDRESS_BYTE    =   7'b000_1000                 ,
                    SEND_DATA       =   7'b001_0000                 ,
                    RECEIVE_DATA    =   7'b010_0000                 ,
                    STOP            =   7'b100_0000                 ;
    
// Signal definition
    reg             [ 6:0]              state_c                     ; // 现态
    reg             [ 6:0]              state_n                     ; // 次态

    wire                                idle2start                  ;
    wire                                start2ctrl_byte             ;
    wire                                ctrl_byte2address_byte      ;
    wire                                ctrl_byte2send_data         ;
    wire                                address_byte2receive_data   ;
    wire                                send_data2stop              ;
    wire                                receive_data2start          ;
    wire                                receive_data2stop           ;
    wire                                stop2idle                   ;

    reg                                 SCL_0                       ; // 对SCL打拍
    reg                                 SCL_1                       ;
    wire                                SCL_podge                   ; // SCL上升沿
    wire                                SCL_nedge                   ; // SCL下降沿

    reg                                 SDA_in_0                    ; // 对SDA_in打拍
    reg                                 SDA_in_1                    ;
    wire                                SDA_in_podge                ; // SDA_in上升沿
    wire                                SDA_in_nedge                ; // SDA_in下降沿

    reg             [ 6:0]              cnt_SCL_low                 ; // 计数SCL低电平
    wire                                add_cnt_SCL_low             ;
    wire                                end_cnt_SCL_low             ;

    reg             [ 3:0]              cnt_bit                     ; // 比特计数器
    wire                                add_cnt_bit                 ;
    wire                                end_cnt_bit                 ;

    reg             [ 3:0]              cnt_byte                    ; // 字节计数器
    wire                                add_cnt_byte                ;
    wire                                end_cnt_byte                ;

    reg                                 flag_block                  ; // 数据块判断
    reg                                 wr_or_rd                    ; // 判断当前写还是读操作

    reg             [ 7:0]              excess_one_byte             ;

    reg             [ 7:0]              data_buff       [ 15:0]     ; // 数据缓存器
    reg             [ 3:0]              pointer_buff                ; // 缓存器指针
    reg             [ 4:0]              data_num                    ; // 数据个数
    reg             [ 3:0]              cnt_data_seq_0              ; // 计数数据序号

    reg             [ 7:0]              data_block_0    [0:255]     ; // 数据块0
    reg             [ 7:0]              pointer_block_0             ; // 数据块0的指针
    reg             [ 7:0]              data_block_1    [0:255]     ; // 数据块1
    reg             [ 7:0]              pointer_block_1             ; // 数据块1的指针

    reg                                 start_display               ; // 数码管开始显示数据
    reg             [ 3:0]              save_data_num               ; // 保存数据个数
    reg             [ 7:0]              data_block_origin           ; // 保存数据块指针值
    wire            [ 7:0]              data_show_pointer           ; // 数据显示的指针
    reg             [ 3:0]              cnt_data_seq_1              ; // 计数数据个数
    reg             [25:0]              cnt_1s                      ; // 计数1秒
    wire                                add_cnt_1s                  ;
    wire                                end_cnt_1s                  ;

// Logic description
    /******************************
        第一段 状态转移
    ******************************/
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_c <= IDLE;
        end
        else begin
            state_c <= state_n;
        end
    end

    /******************************
        第二段 状态转移规律
    ******************************/
    always @(*) begin
        case (state_c)
            IDLE : 
                begin
                    if (idle2start) begin
                        state_n = START;
                    end
                    else begin
                        state_n = IDLE;
                    end
                end
            START :
                begin
                    if (start2ctrl_byte) begin
                        state_n = CTRL_BYTE;
                    end
                    else begin
                        state_n = START;
                    end
                end
            CTRL_BYTE :
                begin
                    if (ctrl_byte2address_byte) begin
                        state_n = ADDRESS_BYTE;
                    end
                    else if (ctrl_byte2send_data) begin
                        state_n = SEND_DATA;
                    end
                    else begin
                        state_n = CTRL_BYTE;
                    end
                end
            ADDRESS_BYTE :
                begin
                    if (address_byte2receive_data) begin
                        state_n = RECEIVE_DATA;
                    end
                    else begin
                        state_n = ADDRESS_BYTE;
                    end
                end
            SEND_DATA :
                begin
                    if (send_data2stop) begin
                        state_n = STOP;
                    end
                    else begin
                        state_n = SEND_DATA;
                    end
                end
            RECEIVE_DATA :
                begin
                    if (receive_data2stop) begin
                        state_n = STOP;
                    end
                    else if (receive_data2start) begin
                        state_n = START;
                    end
                    else begin
                        state_n = RECEIVE_DATA;
                    end
                end
            STOP :
                begin
                    if (stop2idle) begin
                        state_n = IDLE;
                    end
                    else begin
                        state_n = STOP;
                    end
                end
            default : state_n = state_c;
        endcase
    end

    assign idle2start                = SCL && SDA_in_nedge;
    assign start2ctrl_byte           = state_c == START && SCL_nedge;
    assign ctrl_byte2address_byte    = state_c == CTRL_BYTE && ~wr_or_rd && end_cnt_bit;
    assign ctrl_byte2send_data       = state_c == CTRL_BYTE && wr_or_rd && end_cnt_bit;
    assign address_byte2receive_data = state_c == ADDRESS_BYTE && end_cnt_bit;
    assign send_data2stop            = state_c == SEND_DATA && cnt_bit == 'd8 && SDA_in_0 && SCL_0;
    assign receive_data2start        = state_c == RECEIVE_DATA && cnt_bit == 'd0 && SCL && SDA_in_nedge;
    assign receive_data2stop         = state_c == RECEIVE_DATA && SCL_0 && SDA_in_podge;
    assign stop2idle                 = state_c == STOP && ((~wr_or_rd && cnt_data_seq_0 >= data_num - 'd1) || (wr_or_rd && SCL && SDA_in_podge));

    /******************************
        第三段 描述输出
    ******************************/
    // 对SCL打拍
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SCL_0 <= 'd1;
            SCL_1 <= 'd1;
        end
        else begin
            SCL_0 <= SCL;
            SCL_1 <= SCL_0;
        end
    end
    assign SCL_podge = SCL_0 & ~SCL_1; // 检测SCL上升沿
    assign SCL_nedge = ~SCL_0 & SCL_1; // 检测SCL下降沿

    // 对SDA_in打拍
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SDA_in_0 <= 'd1;
            SDA_in_1 <= 'd1;
        end
        else begin
            SDA_in_0 <= SDA_in;
            SDA_in_1 <= SDA_in_0;
        end
    end
    assign SDA_in_podge = SDA_in_0 & ~SDA_in_1; // 检测SDA_in上升沿
    assign SDA_in_nedge = ~SDA_in_0 & SDA_in_1; // 检测SDA_in下降沿

    // 计数SCL低电平
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_SCL_low <= 'd0;
        end
        else if (add_cnt_SCL_low) begin
            if (end_cnt_SCL_low) begin
                cnt_SCL_low <= cnt_SCL_low;
            end
            else begin
                cnt_SCL_low <= cnt_SCL_low + 'd1;
            end
        end
        else begin
            cnt_SCL_low <= 'd0;
        end
    end
    assign add_cnt_SCL_low = state_c >= CTRL_BYTE && ~SCL_0;
    assign end_cnt_SCL_low = add_cnt_SCL_low && cnt_SCL_low >= SCL_LOW_HOUD - 'd1;

    // 比特计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_bit <= 'd0;
        end
        else if (state_c == START || state_c == STOP) begin
            cnt_bit <= 'd0;
        end
        else if (add_cnt_bit) begin
            if (end_cnt_bit) begin
                cnt_bit <= 'd0;
            end
            else begin
                cnt_bit <= cnt_bit + 'd1;
            end
        end
        else begin
            cnt_bit <= cnt_bit;
        end
    end
    assign add_cnt_bit = state_c >= CTRL_BYTE && state_c < STOP && (SCL_nedge || send_data2stop);
    assign end_cnt_bit = add_cnt_bit && cnt_bit >= 'd8;

    // 字节计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_byte <= 'd0;
        end
        else if (state_c == START || state_c == STOP) begin
            cnt_byte <= 'd0;
        end
        else if (add_cnt_byte) begin
            if (end_cnt_byte) begin
                cnt_byte <= 'd0;
            end
            else begin
                cnt_byte <= cnt_byte + 'd1;
            end
        end
        else begin
            cnt_byte <= cnt_byte;
        end
    end
    assign add_cnt_byte = state_c == RECEIVE_DATA && end_cnt_bit;
    assign end_cnt_byte = add_cnt_byte && cnt_byte >= 'd15;

    // 判断数据块
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flag_block <= 'd0;
        end
        else if (state_c == CTRL_BYTE && cnt_bit == 6 && SCL_0) begin
            flag_block <= SDA_in_0;
        end
        else begin
            flag_block <= flag_block;
        end
    end

    // 判断当前是写还是读操作
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_or_rd <= 'd0;
        end
        else if (stop2idle) begin
            wr_or_rd <= 'd0;
        end
        else if (state_c == CTRL_BYTE && cnt_bit == 'd7 && SCL_0) begin
            wr_or_rd <= SDA_in_0;
        end
        else begin
            wr_or_rd <= wr_or_rd;
        end
    end

    // 缓存一个字节
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            excess_one_byte <= 'd0;
        end
        else if (state_c == RECEIVE_DATA && SCL_0) begin
            excess_one_byte[7 - cnt_bit] <= SDA_in_0;
        end
        else if (state_c == SEND_DATA) begin
            if (flag_block) begin
                excess_one_byte <= data_block_1[pointer_block_1];
            end
            else begin
                excess_one_byte <= data_block_0[pointer_block_0];
            end
        end
        else begin
            excess_one_byte <= excess_one_byte;
        end
    end

    // 缓存器指针
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer_buff <= 'd0;
        end
        else if ((state_c == RECEIVE_DATA || state_c == STOP) && ~wr_or_rd) begin
            if (end_cnt_bit || receive_data2stop || state_c == STOP) begin
                if (pointer_buff >= 'd15) begin
                    pointer_buff <= 'd0;
                end
                else if (receive_data2stop) begin
                    if (data_num <= 'd15) begin
                        pointer_buff <= 'd0;
                    end
                    else begin
                        pointer_buff <= pointer_buff;
                    end
                end
                else begin
                    pointer_buff <= pointer_buff + 'd1;
                end
            end
            else begin
                pointer_buff <= pointer_buff;
            end
        end
        else begin
            pointer_buff <= 'd0;
        end
    end

    // 缓存所有的数据，超过16byte覆盖
    always @(posedge clk) begin
        if (state_c == RECEIVE_DATA && end_cnt_bit) begin
            data_buff[pointer_buff] <= excess_one_byte;
        end
    end

    // 记录接收的数据字节个数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_num <= 'd0;
        end
        else if ((state_c == RECEIVE_DATA || state_c == STOP) && ~wr_or_rd) begin
            if (end_cnt_bit) begin
                if (data_num >= 'd15) begin
                    data_num <= 'd16;
                end
                else begin
                    data_num <= data_num + 'd1;
                end
            end
            else begin
                data_num <= data_num;
            end
        end
        else begin
            data_num <= 'd0;
        end
    end

    // 将缓存器中的数据存入数据块中需要计数数据序号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_data_seq_0 <= 'd0;
        end
        else if (state_c == STOP && ~wr_or_rd) begin
            if (cnt_data_seq_0 >= data_num - 'd1) begin
                cnt_data_seq_0 <= 'd0;
            end
            else begin
                cnt_data_seq_0 <= cnt_data_seq_0 + 'd1;
            end
        end
        else begin
            cnt_data_seq_0 <= 'd0;
        end
    end

    // 数据块0的指针
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer_block_0 <= 'd0;
        end
        else if (~flag_block) begin
            if (state_c == ADDRESS_BYTE && cnt_bit <= 'd7 && SCL_0) begin
                pointer_block_0[7 - cnt_bit] <= SDA_in_0;
            end
            else if ((~wr_or_rd && state_c == STOP) || (state_c == SEND_DATA && end_cnt_bit)) begin
                if (pointer_block_0 >= 'd255) begin
                    pointer_block_0 <= 'd0;
                end
                else begin
                    pointer_block_0 <= pointer_block_0 + 'd1;
                end
            end
            else begin
                pointer_block_0 <= pointer_block_0;
            end
        end
        else begin
            pointer_block_0 <= pointer_block_0;
        end
    end

    // 数据块0
    always @(posedge clk) begin
        if (state_c == STOP && ~flag_block && ~wr_or_rd) begin
            data_block_0[pointer_block_0] <= data_buff[pointer_buff];
        end
    end

    // 数据块1的指针
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer_block_1 <= 'd0;
        end
        else if (flag_block) begin
            if (state_c == ADDRESS_BYTE && cnt_bit <= 'd7 && SCL_0) begin
                pointer_block_1[7 - cnt_bit] <= SDA_in_0;
            end
            else if ((~wr_or_rd && state_c == STOP) || (state_c == SEND_DATA && end_cnt_bit)) begin
                if (pointer_block_1 >= 'd255) begin
                    pointer_block_1 <= 'd0;
                end
                else begin
                    pointer_block_1 <= pointer_block_1 + 'd1;
                end
            end
            else begin
                pointer_block_1 <= pointer_block_1;
            end
        end
        else begin
            pointer_block_1 <= pointer_block_1;
        end
    end

    // 数据块1
    always @(posedge clk) begin
        if (state_c == STOP && ~flag_block && ~wr_or_rd) begin
            data_block_1[pointer_block_1] <= data_buff[pointer_buff];
        end
    end

    // SDA_out输出数据
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SDA_out <= 'd0;
            SDA_oe <= 'd0;
        end
        else if (state_c == SEND_DATA) begin
            if (cnt_SCL_low == CHANGE_TIME) begin
                if (cnt_bit <= 'd7) begin
                    SDA_oe <= 'd1;
                    SDA_out <= excess_one_byte[7 - cnt_bit];
                end
                else begin
                    SDA_out <= 'd0;
                    SDA_oe <= 'd0;
                end
            end
            else begin
                SDA_out <= SDA_out;
                SDA_oe <= SDA_oe;
            end
        end
        else begin
            if (cnt_SCL_low == CHANGE_TIME) begin
                case (cnt_bit)
                    'd0 : begin SDA_out <= 'd0; SDA_oe <= 'd0; end
                    'd8 : begin SDA_out <= 'd0; SDA_oe <= 'd1; end
                    default: begin SDA_out <= SDA_out; SDA_oe <= SDA_oe; end
                endcase
            end
            else begin
                SDA_out <= SDA_out;
                SDA_oe <= SDA_oe;
            end
        end
    end

    // 数码管开始显示数据
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_display <= 'd0;
        end
        else if (stop2idle) begin
            start_display <= 'd1;
        end
        else begin
            start_display <= start_display;
        end
    end

    // 保存数据个数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            save_data_num <= 'd0;
        end
        else if (stop2idle && ~wr_or_rd) begin
            save_data_num <= data_num - 'd1;
        end
        else begin
            save_data_num <= save_data_num;
        end
    end

    // 保存数据块指针值
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_block_origin <= 'd0;
        end
        else if (stop2idle && ~wr_or_rd) begin
            if (flag_block) begin
                data_block_origin <= pointer_block_1 + 'd1 - data_num;
            end
            else begin
                data_block_origin <= pointer_block_0 + 'd1 - data_num;
            end
        end
        else begin
            data_block_origin <= data_block_origin;
        end
    end

    // 计数1s
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1s <= 'd0;
        end
        else if (add_cnt_1s) begin
            if (end_cnt_1s) begin
                cnt_1s <= 'd0;
            end
            else begin
                cnt_1s <= cnt_1s + 'd1;
            end
        end
        else begin
            cnt_1s <= 'd0;
        end
    end
    assign add_cnt_1s = 1'd1;
    assign end_cnt_1s = add_cnt_1s && cnt_1s >= S_1 - 'd1;

    // 计数数据个数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_data_seq_1 <= 'd0;
        end
        else if (stop2idle && ~wr_or_rd) begin
            cnt_data_seq_1 <= 'd0;
        end
        else if (end_cnt_1s) begin
            if (cnt_data_seq_1 >= save_data_num) begin
                cnt_data_seq_1 <= 'd0;
            end
            else begin
                cnt_data_seq_1 <= cnt_data_seq_1 + 'd1;
            end
        end
        else begin
            cnt_data_seq_1 <= cnt_data_seq_1;
        end
    end

    assign data_show_pointer = data_block_origin + cnt_data_seq_1;

    // 发送数据给数码管显示
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 'd0;
        end
        else if (start_display) begin
            data_out <= data_block_0[data_show_pointer];
        end
        else begin
            data_out <= 'd0;
        end
    end

endmodule