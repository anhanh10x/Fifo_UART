//================================================================================================
//------------------------------------------module UART_RX----------------------------------------
//================================================================================================
module uart_rx
#(
    parameter		DATA_BIT           				= 8			,       // # data bits
					PARITY_BIT_EN         			= 0			,       // 0 <=> NONE, 1 <=> USED
					STOP_BIT           				= 0			,	    // 0 <=> 1 bit, 1 <=> 1,5 bit, 2 <=> 2 bit
					DATA_BUFFER_LENGTH_WIDTH        = 8			,	 	// 0 <=> 1 bit, 1 <=> 1,5 bit, 2 <=> 2 bit		
					DATA_BLOCK_SIZE					= 16		
)
(
	input                             				clk									,                
    input                             				reset								,
	input											rx_en								,              
    input 		[24: 0]                 			baud_divisor						,       
    input 		                        			rx									,                
    input	 	[DATA_BUFFER_LENGTH_WIDTH-1:0]		data_buffer_readaddress				,
	input 		[7:0] 								uart_irq_when_received_message_num	,
	output reg                          			rx_done								,                
   	output reg    									error_flag							,
	output wire [7:0]								data_buffer_readdata				,
	output reg	[7:0]								message_received_count				,
	output reg 							            pingpong_pointer        		
);

	reg 	[7:0]								data_buffer_writedata				;
	reg 	[DATA_BUFFER_LENGTH_WIDTH-1:0]		data_buffer_writeaddress			;
	reg 										data_buffer_writeen					;
	reg 	[2:0] 								state								;
	reg 										cal_parity							;
	reg											received_flag						;
	reg		[3:0]								data_count_reg						;
	reg 	[24:0]            					baud_count_reg						;      // baud rate count
	reg 										sampling_en_flag					;
	reg 	[DATA_BIT-1:0]     					rx_data_raw							;      
	reg 										data_stable							;
	reg		[7:0]								data_buffer							;
	reg 	[24: 0]                 			stop_bit_div						;
	reg		[7:0]								internal_message_received_count		;
	reg											pingpong_pointer_internal       	;
	
	//Tham so cua he thong
	localparam 	ADDRESS_BUFFER_A 				=	0,
				ADDRESS_BUFFER_B 				=	DATA_BLOCK_SIZE;

	localparam 	PINGPONG_POINTER_A 				=	1'b0,
				PINGPONG_POINTER_B 				=	1'b1;

	//UART FSM State
	localparam 
		IDLE 		= 	0	, 
		START 		= 	1	, 
		DATA 		= 	2	, 
		PARITY 		= 	3	, 
		STOP 		= 	4	,
		SAVE_DATA	=	5	,
		PING_PONG	=	6	;

	always @*
	case (STOP_BIT)
		2'b00: stop_bit_div = baud_divisor						;   // 1   Stop Bit
		2'b01: stop_bit_div = baud_divisor + baud_divisor>>1	; 	// 1.5 Stop Bit
		2'b10: stop_bit_div = baud_divisor + baud_divisor		;  	// 2   Stop Bit
		2'b11: stop_bit_div = baud_divisor						;
	endcase

	//====================================================================================================================
	// SAMPLING DATA
    //====================================================================================================================
	always @(posedge clk)
	begin
		if (~reset)
		begin
			data_stable			<=	1'b0;
			data_buffer			<=  0	;
		end
		else begin
			if(rx_en)
			begin
				data_buffer	<=	{data_buffer[6:0], rx};
				if (sampling_en_flag)
				begin
					if (data_buffer[7:2] == 6'b111111)
					begin
						data_stable		<=	1'b1;
						received_flag	<= 	1'b1;
					end	
					else if (data_buffer[7:2] == 6'b000000)
					begin
						data_stable		<= 	1'b0;
						received_flag	<= 	1'b1;
					end
				end
				else begin
					received_flag	<= 	1'b0;
				end
			end
		end
	end

   	//====================================================================================================================
	// RX FSM
    //====================================================================================================================
	always @(posedge clk) 
	begin
		if (~reset)
		begin
			state 							<= 	IDLE	;
			cal_parity 						<= 	1'b1	;
			baud_count_reg					<= 	0		;
			rx_data_raw						<=	0		;
			data_count_reg					<=	0		;
			error_flag						<= 	1'b0	;
			message_received_count			<=	0		;
			internal_message_received_count	<=	0		;
			pingpong_pointer_internal       <=  PINGPONG_POINTER_A;
        	pingpong_pointer                <=  PINGPONG_POINTER_A;
			data_buffer_writeaddress		<=	ADDRESS_BUFFER_A  ;
			data_buffer_writeen				<=	0		;
			rx_done							<=	0		;
			sampling_en_flag				<= 	1'b0	;
		end
		else begin
			if(rx_en)
			begin
				case(state)
					IDLE: begin
						rx_data_raw			<=	0		;
						cal_parity 			<= 	1'b1	;
						baud_count_reg		<= 	0		;
						sampling_en_flag	<= 	1'b0	;
						data_count_reg		<=	0		;
						error_flag			<= 	1'b0	;
						rx_done				<=	0		;
						data_buffer_writeen <=	1'b0	;
						if (!rx) 
							state <= START;
						else 
							state <= IDLE;
					end
					START: begin
						if (baud_count_reg == baud_divisor>>1)
						begin
							sampling_en_flag	<= 	1'b1			;
							if(received_flag)
							begin
								if(data_stable == 1'b0) begin
									baud_count_reg		<= 	0		;
									sampling_en_flag	<= 	1'b0	;
									state 				<= 	DATA	;
								end
							end
						end
						else begin
							baud_count_reg <= baud_count_reg + 1	;
						end
					end
					DATA: begin
						if(data_count_reg == DATA_BIT - PARITY_BIT_EN) 
						begin
							if (PARITY_BIT_EN)
								state <= PARITY	;
							else
								state <= STOP	;
						end
						else begin
							if (baud_count_reg == baud_divisor)
							begin
								sampling_en_flag 		<= 	1'b1													;
								if (received_flag)
								begin
									rx_data_raw			<= 	{rx_data_raw[DATA_BIT-2:0], data_stable}				;
									cal_parity 			<=	cal_parity&(~data_stable) | (~cal_parity)&data_stable	;
									data_count_reg 		<= 	data_count_reg + 1										;
									baud_count_reg 		<=  0														;
									sampling_en_flag	<= 	1'b0													;
									state 				<= 	DATA													;
								end
							end else 
							begin
								baud_count_reg 			<= baud_count_reg + 1										;
							end
						end
					end
					PARITY: begin
						if (baud_count_reg == baud_divisor)
						begin
							sampling_en_flag	<= 	1'b1			;
							if(received_flag)
							begin
								if(cal_parity == ~data_stable)
								begin
									baud_count_reg		<= 0		;
									sampling_en_flag	<= 1'b0		;
								end
								else begin
									error_flag			<= 1'b1		;
								end
								state 				<= STOP			;		
							end
						end
						else begin
							baud_count_reg <= baud_count_reg + 1	;
						end
					end
					STOP: 
					begin
						if (baud_count_reg == stop_bit_div)
						begin
							sampling_en_flag	<= 	1'b1			;
							if(received_flag)
							begin
								if(data_stable == 1'b1)
								begin
									if(!error_flag)
									begin
										state  <=  SAVE_DATA;
									end
									else
									begin
										state  <= 	IDLE;
									end
									baud_count_reg	 	<= 	0;
									sampling_en_flag	<= 	1'b0;
								end
							end
						end
						else begin
							baud_count_reg <= baud_count_reg + 1;
						end
					end
					SAVE_DATA:
					begin
						data_buffer_writedata 			<=  rx_data_raw						;
						data_buffer_writeen 			<=	1'b1							;
						state							<= 	PING_PONG						;
					end
					PING_PONG:
					begin
						data_buffer_writeaddress 		<=	data_buffer_writeaddress + 1'b1	;
						data_buffer_writeen 			<=	1'b0							;
						internal_message_received_count	<=  internal_message_received_count + 1;
						state							<= 	IDLE;
						if(internal_message_received_count + 1 >= uart_irq_when_received_message_num)
						begin
							rx_done										<=	1'b1;
							message_received_count						<=  internal_message_received_count + 1;
							internal_message_received_count				<=	0;
							pingpong_pointer 							<=	pingpong_pointer_internal;
							pingpong_pointer_internal 					<=	~pingpong_pointer_internal;
						
							if (pingpong_pointer_internal == PINGPONG_POINTER_A)
							begin
								data_buffer_writeaddress 	<=	ADDRESS_BUFFER_B;
							end
							else
							begin
								data_buffer_writeaddress 	<=	ADDRESS_BUFFER_A;
							end
						end
					end
				endcase
			end
		end
	end

	//====================================================================================================================
	//Connect to buffer
    //====================================================================================================================
	buffer
	#(
		.DATA_BIT 				     (DATA_BIT)  		      ,
		.DATA_BUFFER_LENGTH_WIDTH    (DATA_BUFFER_LENGTH_WIDTH)
	) data_buffer_ins
	(
		.clk 		(clk 									),
		.reset_n	(reset									),
		.data 		(data_buffer_writedata 					),
		.rdaddress 	(data_buffer_readaddress 				),
		.wraddress 	(data_buffer_writeaddress 				),
		.wren 		(data_buffer_writeen 					),
		.q 			(data_buffer_readdata 					)
	);

endmodule
