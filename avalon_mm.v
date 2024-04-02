//===================================================================================================================
//-----------------------------------------module Avalon_MM----------------------------------------------------------
//===================================================================================================================
`timescale 1ns/1ps
module avalon_mm 
#(
    parameter       CORE_FREQUENCY              = 50000000  ,
                    BAUDRADE                    = 921600    ,
         	        DATA_BIT           	        = 8         ,      // # data bits
     	 		    PARITY_BIT_EN         	    = 0         ,      // 0 <=> NONE, 1 <=> USED
                    STOP_BIT           		    = 0         ,	   // 0 <=> 1 bit, 1 <=> 1,5 bit, 2 <=> 2 bit
	                DATA_BUFFER_LENGTH_WIDTH    = 8
)
(
    input   wire                clk                ,
    input   wire                reset_n            ,
    //avalon mm interface
    input   wire    [9:0]       address            ,
    input   wire                write_n            ,
    input   wire    [31:0]      writedata          ,
    input   wire                read_n             ,
    output  reg     [31:0]      readdata           ,
    output  wire                waitrequest        ,
    //conduit
    input  wire                 uart_rx            ,
    output wire 				uart_tx            ,
    //interrupt sender
    output wire                 irq                
);

//=====================================================================================================================
// Local parameter Definition
//=====================================================================================================================

    localparam      UART_DIVISOR_DEFAULT     =   CORE_FREQUENCY/BAUDRADE - 1,
                    BUFFER_READ_CLOCKS       =   2                          ;
    
    localparam      ADDRESS_UART_TX_EN                                                                      =   0       ,
                    ADDRESS_UART_RX_EN                                                                      =   1       ,
                    ADDRESS_UART_DIVISOR                                                                    =   2       ,
                    ADDRESS_CLEAR_IRQ                                                                       =   3       ,
                    ADDRESS_UART_IRQ_WHEN_RECEIVED_MESSAGE_NUM_SET                                          =   4       ,
                    ADDRESS_UART_TX_TE_SET                                                                  =   5       ,
                    ADDRESS_UART_TX_DR_SET                                                                  =   6       ,
                    ADDRESS_UART_MESSAGE_RECEIVED_NUM                                                       =   7       ,
                    ADDRESS_UART_TX_DONE_COUNTER                                                            =   8       ,
                    ADDRESS_UART_RX_DONE_COUNTER                                                            =   9       ,
                    ADDRESS_UART_RX_ERROR_COUNTER                                                           =   10      ,
                    ADDRESS_UART_SR                                                                         =   11      ,
                    ADDRESS_DATA_BUFFER                                                                     =   12      ;

//=====================================================================================================================
// Wire, Register Definition
//=====================================================================================================================
    wire                                                   clr_irq                             ;
    reg                                                    irq_reg                             ;
    reg 		[24:0] 		                               baud_divisor			               ;
	reg 					                               tx_en					           ;
    reg					                                   tx_te					           ;
    reg 		[7:0] 		                               tx_dr					           ;
    reg                                                    rx_en                               ;
    wire        [7:0]                                      uart_sr                             ;
    wire        [7:0]                                      rx_done_count                       ;
    wire        [7:0]                                      tx_done_count                       ;
    wire     	[7:0] 	                                   rx_error_count			           ;
    wire                                                   data_buffer_pingpong_pointer        ;
    reg         [DATA_BUFFER_LENGTH_WIDTH-1:0]             data_buffer_readaddress             ;
    wire        [7:0]                                      data_buffer_readdata                ;
    reg         [2:0]                                      data_buffer_read_wait_counter       ;
    reg         [7:0]                                      uart_irq_when_received_message_num  ;
    wire        [4:0]                                      message_received_count              ;

//=====================================================================================================================
// registers for read/write decoding
//=====================================================================================================================

//=====================================================================================================================
// read data
//=====================================================================================================================
    always @(posedge clk)
    begin
        if(~reset_n)
        begin
            tx_en                                       <= 1'b0;
            rx_en                                       <= 1'b0;
            tx_te                                       <= 1'b0;
            tx_dr                                       <= 0;
            baud_divisor                                <= UART_DIVISOR_DEFAULT;
            irq_reg                                     <= 1'b0;
            uart_irq_when_received_message_num          <= 1;
        end
        else
        begin
            if (~write_n)
            begin
                case (address)
                    ADDRESS_UART_TX_EN: 
                    begin
                        tx_en           <=  writedata[0];
                    end
                    ADDRESS_UART_RX_EN:
                    begin
                        rx_en           <=  writedata[0];
                    end
                    ADDRESS_UART_DIVISOR:
                    begin
                        baud_divisor    <=  writedata[24:0];
                    end
                    ADDRESS_CLEAR_IRQ:
                    begin
                        irq_reg     <=  1'b0;
                    end
                    ADDRESS_UART_IRQ_WHEN_RECEIVED_MESSAGE_NUM_SET:
                    begin
                        uart_irq_when_received_message_num     <=  writedata[7:0];
                    end
                    ADDRESS_UART_TX_TE_SET:
                    begin
                        tx_te      <=  writedata[0];     
                    end
                    ADDRESS_UART_TX_DR_SET:
                    begin
                        tx_dr          <=  writedata[7:0];
                    end 
                endcase
            end
            if ((uart_sr[1]&&tx_en))
            begin
                irq_reg         <=  1'b1;
            end
            else begin
                irq_reg         <=  1'b0;
            end
        end
    end

    assign  irq = irq_reg; 

//=====================================================================================================================
// write data
//=====================================================================================================================
    reg     read_done;
    assign  waitrequest     =   (~read_n & ~read_done);

    always @(posedge clk)
    begin
        if (~reset_n)
        begin
            read_done                       <=  0;
            data_buffer_readaddress         <=  0;
            data_buffer_read_wait_counter   <=  0;
        end 
        else
        begin
            read_done   <=  1'b0;
            data_buffer_read_wait_counter   <=  0;
            if (~read_n & ~read_done)
            begin
                case (address)
                    ADDRESS_UART_TX_EN:
                    begin
                        readdata    <=  {31'b0, tx_en};
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_RX_EN:
                    begin
                        readdata    <=  {31'b0, rx_en};
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_DIVISOR:
                    begin
                        readdata    <=  {8'b0, baud_divisor};
                        read_done   <=  1'b1;
                    end
                    ADDRESS_CLEAR_IRQ:
                    begin
                        readdata    <=  {31'b0, irq_reg};
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_IRQ_WHEN_RECEIVED_MESSAGE_NUM_SET:
                    begin
                        readdata    <=  uart_irq_when_received_message_num;
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_TX_TE_SET:
                    begin
                        readdata    <=  0;
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_TX_DR_SET:
                    begin
                        readdata    <=  0;
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_MESSAGE_RECEIVED_NUM:
                    begin
                        readdata    <=  {24'b0, message_received_count};
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_TX_DONE_COUNTER:
                    begin
                        readdata    <=  {24'b0, tx_done_count};
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_RX_DONE_COUNTER:
                    begin
                        readdata    <=  {24'b0,rx_done_count};
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_RX_ERROR_COUNTER:
                    begin
                        readdata    <=  {24'b0,rx_error_count};
                        read_done   <=  1'b1;
                    end
                    ADDRESS_UART_SR:
                    begin
                        readdata    <=  {24'b0, uart_sr};
                        read_done   <=  1'b1;
                    end
                    default:
                    begin
                        data_buffer_readaddress             <=  address - ADDRESS_DATA_BUFFER;
                        data_buffer_read_wait_counter       <=  data_buffer_read_wait_counter + 1'b1;
                        if (data_buffer_read_wait_counter == BUFFER_READ_CLOCKS + 1'b1)
                        begin
                            readdata                        <=  {24'd0, data_buffer_readdata};
                            data_buffer_read_wait_counter   <=  0;
                            read_done                       <=  1'b1;
                        end
                    end 
                endcase // address
            end
        end
    end

    //=====================================================================================================================
    // connection to uart_controller_top module
    //=====================================================================================================================
    uart_controller_top
    #(
        .DATA_BIT                   (DATA_BIT                   ),
        .PARITY_BIT_EN              (PARITY_BIT_EN              ), 
        .STOP_BIT                   (STOP_BIT                   ),
	    .DATA_BUFFER_LENGTH_WIDTH   (DATA_BUFFER_LENGTH_WIDTH   )
    ) uart_controller_top_inst
    ( 
        .clk	                            (clk)					                ,
	    .reset_n                            (reset_n)					            ,
        .baud_divisor                       (baud_divisor)			                ,
	    .tx_en                              (tx_en)					                ,
        .tx_te                              (tx_te)					                ,
        .tx_dr                              (tx_dr)					                ,
        .rx                                 (uart_rx)					            ,
        .rx_en                              (rx_en)                                 ,
        .uart_irq_when_received_message_num (uart_irq_when_received_message_num)    ,
        .tx                                 (uart_tx)                               ,
        .uart_sr                            (uart_sr)                               ,
        .rx_done_count                      (rx_done_count)                         ,
        .tx_done_count                      (tx_done_count)                         ,
        .rx_error_count                     (rx_error_count)			            ,
        .data_buffer_readaddress            (data_buffer_readaddress)	            ,
	    .data_buffer_readdata	            (data_buffer_readdata)                 	,
        .message_received_count             (message_received_count)                
    );

endmodule


