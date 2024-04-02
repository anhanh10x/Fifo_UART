//================================================================================================
//-------------------------------module UART_controller_top---------------------------------------
//================================================================================================
module uart_controller_top
#(
    parameter 	    DATA_BIT           				= 8	    ,       // # data bits
                    PARITY_BIT_EN         			= 0		,       // 0 <=> NONE, 1 <=> USED
                    STOP_BIT           				= 0		,	    // 0 <=> 1 bit, 1 <=> 1,5 bit, 2 <=> 2 bit
                    DATA_BUFFER_LENGTH_WIDTH        = 8		,
                    DATA_BLOCK_SIZE	 	            = 16        
)
(   
    input 					                        clk						            ,
	input                                           reset_n					            ,
    input 		[24:0] 		                        baud_divisor			            ,
	input 					                        tx_en					            ,
    input 					                        tx_te					            ,
    input 		[7:0] 		                        tx_dr					            ,
    input 		                                    rx					                ,
    input                                           rx_en                               ,
    input	 	[DATA_BUFFER_LENGTH_WIDTH-1:0]		data_buffer_readaddress	            ,
    input       [7:0]                               uart_irq_when_received_message_num  ,
    output wire 				                    tx                                  ,
    output reg  [7:0]                               uart_sr                             ,
    output reg  [7:0]                               rx_done_count                       ,
    output reg  [7:0]                               tx_done_count                       ,
    output reg 	[7:0] 	                            rx_error_count			            ,
	output wire [7:0]		                        data_buffer_readdata	            ,
    output wire [7:0]                               message_received_count              
);

    //Tham so cua he thong
	localparam 	ADDRESS_BUFFER_A 				=	0,
				ADDRESS_BUFFER_B 				=	DATA_BLOCK_SIZE;

	localparam 	PINGPONG_POINTER_A 				=	1'b0,
				PINGPONG_POINTER_B 				=	1'b1;

    wire    rx_done          ;
    wire    tx_done          ;
    wire    error_flag       ;
    wire    pingpong_pointer ;
    reg	    [DATA_BUFFER_LENGTH_WIDTH-1:0]		data_buffer_readaddress_internal;

    always @(posedge clk)
    begin
        if (~reset_n)
        begin
            rx_done_count   <= 0;
            tx_done_count   <= 0;
            rx_error_count  <= 0;
            uart_sr         <= 0;
            data_buffer_readaddress_internal <= 0;
        end
        else begin
            uart_sr   <=   {5'b00000, error_flag, tx_done, rx_done};
            if(rx_done)
                rx_done_count   <= rx_done_count + uart_irq_when_received_message_num    ;
            if(tx_done)
                tx_done_count   <= tx_done_count + 1;
            if(error_flag)
                rx_error_count  <= rx_error_count + 1   ;
            
            if(pingpong_pointer == PINGPONG_POINTER_A)
            begin
                data_buffer_readaddress_internal <= data_buffer_readaddress;
            end
            else if(pingpong_pointer == PINGPONG_POINTER_B)
            begin
                data_buffer_readaddress_internal <= data_buffer_readaddress + DATA_BLOCK_SIZE;
            end
        end
    end

	uart_tx
    #(
        .DATA_BIT                   (DATA_BIT                   ),
        .PARITY_BIT_EN              (PARITY_BIT_EN              ), 
        .STOP_BIT                   (STOP_BIT                   ),
	    .DATA_BUFFER_LENGTH_WIDTH   (DATA_BUFFER_LENGTH_WIDTH   ) 	
    ) uart_tx_inst
    (
    	.clk			        (clk                ),
		.reset			        (reset_n            ),
    	.tx_en                  (tx_en              ),
        .baud_divisor	        (baud_divisor       ),
		.tx_te			        (tx_te              ),
    	.tx_dr			        (tx_dr              ),
		.tx_done			    (tx_done            ),
    	.tx				        (tx                 )
	);  

	uart_rx
    #(
        .DATA_BIT                   (DATA_BIT                   ),
        .PARITY_BIT_EN              (PARITY_BIT_EN              ), 
        .STOP_BIT                   (STOP_BIT                   ),
	    .DATA_BUFFER_LENGTH_WIDTH   (DATA_BUFFER_LENGTH_WIDTH   ),
        .DATA_BLOCK_SIZE            (DATA_BLOCK_SIZE            )    	 	
    ) uart_rx_inst
    (
	    .clk                                (clk                                  ),                
        .reset					            (reset_n                              ),
	    .rx_en                              (rx_en                                ),              
        .baud_divisor                       (baud_divisor                         ),       
        .rx	                                (rx                                   ),                
        .data_buffer_readaddress            (data_buffer_readaddress_internal     ),
	    .uart_irq_when_received_message_num (uart_irq_when_received_message_num   ),
	    .rx_done                            (rx_done                              ),                
   	    .error_flag                         (error_flag                           ),
	    .data_buffer_readdata               (data_buffer_readdata                 ),
        .message_received_count             (message_received_count               ),
        .pingpong_pointer                   (pingpong_pointer                     )
	);

endmodule
