/*========================================*\
    filename        : IIC_demo.v
    description     : IIC顶层模块
    up file         : 
    reversion       : 
        v1.0 : 2022-8-16 13:47:37
    author          : 张某某
\*========================================*/

module IIC_demo_top (
    input                               clk             ,
    input                               rst_n           ,
    input                               SCL             ,

    inout                               SDA             ,

    output          [ 5:0]              SEL             ,
    output          [ 7:0]              DIG
);

// Parameter definition
    

// Signal definition
    wire                                SDA_in          ;
    wire                                SDA_out         ;
    wire                                SDA_oe          ;
    wire            [ 7:0]              data            ;

// Module calls
    IIC                 U_IIC(
        /*input                 */      .clk        (clk    ),
        /*input                 */      .rst_n      (rst_n  ),
        /*input                 */      .SCL        (SCL    ),
        /*input                 */      .SDA_in     (SDA_in ),
        /*output  reg           */      .SDA_out    (SDA_out),
        /*output  reg           */      .SDA_oe     (SDA_oe ),
        /*output  reg     [ 7:0]*/      .data_out   (data   )
    );

    display             U_display(
        /*input                 */      .clk        (clk    ),   // 50MHz
        /*input                 */      .rst_n      (rst_n  ),   // 复位信号
        /*input           [ 7:0]*/      .data       (data   ),
        /*output  reg     [ 5:0]*/      .SEL        (SEL    ),   // SEL信号
        /*output  reg     [ 7:0]*/      .DIG        (DIG    )    // DIG信号
    );

// Logic description
    assign SDA_in = SDA;
    assign SDA = SDA_oe ? SDA_out : 1'bz;

endmodule
