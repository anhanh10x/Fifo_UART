//================================================================================================
//------------------------------------------module UART_TX----------------------------------------
//================================================================================================
module uart_tx
#(
    parameter		DATA_BIT           				= 8			,       // # data bits
					PARITY_BIT_EN         			= 0			,       // 0 <=> NONE, 1 <=> USED
					STOP_BIT           				= 0			,	    // 0 <=> 1 bit, 1 <=> 1,5 bit, 2 <=> 2 bit
					DATA_BUFFER_LENGTH_WIDTH        = 8				 	// 0 <=> 1 bit, 1 <=> 1,5 bit, 2 <=> 2 bit 
)
(
    input 					clk						,
	input                   reset					,
	input					tx_en					,
    input 		[24:0] 		baud_divisor			,
	input 					tx_te					, 
    input 		[7:0] 		tx_dr					,
	output reg 				tx_done					,
    output reg 				tx
);

	reg 	[2:0] 			state					;
	reg 					cal_parity				;
	reg		[3:0]			data_count_reg			;
	reg 	[24:0]          baud_count_reg			;
	reg 	[24:0]         	stop_bit_div			;
	reg						pre_tx_te				;

	always @*
	case (STOP_BIT)
		2'b00: stop_bit_div <= baud_divisor						;   // 1   Stop Bit
		2'b01: stop_bit_div <= baud_divisor + baud_divisor>>1	; 	// 1.5 Stop Bit
		2'b10: stop_bit_div <= baud_divisor + baud_divisor		;  	// 2   Stop Bit
		2'b11: stop_bit_div <= baud_divisor						;
	endcase

	localparam 
		START_BIT 	= 	0	, 
		END_BIT 	= 	1	;

	//UART FSM State
	localparam 
		IDLE 	= 	0	, 
		START 	= 	1	, 
		DATA 	= 	2	, 
		PARITY 	= 	3	, 
		STOP 	= 	4	;

   	//====================================================================================================================
	// TX FSM
    //====================================================================================================================
	always @(posedge clk) 
	begin
		if (~reset)
		begin
			state 			<= 	IDLE	;
			cal_parity 		<= 	1'b1	;
			baud_count_reg	<= 	0		;
			data_count_reg	<=	0		;
			tx 				<= 	1		;
			tx_done			<=	0		;
		end
		else begin
			if(tx_en)
			begin
				case(state)
					IDLE: begin
						cal_parity 		<= 	1'b1	;
						baud_count_reg	<= 	0		;
						data_count_reg	<=	0		;
						tx 				<= 	1		;
						tx_done			<=	0		;
						if(tx_te && !pre_tx_te)
						begin
							state <= START;
						end
					end
					START: begin
						tx <= START_BIT;
						if (baud_count_reg >= baud_divisor)
						begin
							tx 					<= 	tx_dr[7-data_count_reg]																;
							cal_parity 			<=	(cal_parity)&(~tx_dr[7-data_count_reg]) | (~cal_parity)&(tx_dr[7-data_count_reg])	;
							data_count_reg 		<= 	data_count_reg + 1																	;
							baud_count_reg		<=	0																					;
							state 				<= 	DATA																				;
						end
						else begin
							baud_count_reg <= baud_count_reg + 1;
						end
					end
					DATA: begin
						if (baud_count_reg >= baud_divisor)
						begin
							if (data_count_reg >= DATA_BIT - PARITY_BIT_EN) 
							begin
								baud_count_reg 			<=  0		;
								if (PARITY_BIT_EN)
									state 				<= PARITY	;
								else
									state 				<= STOP		;
							end
							else begin
								tx 					<= 	tx_dr[7-data_count_reg]																;
								cal_parity 			<=	(cal_parity)&(~tx_dr[7-data_count_reg]) | (~cal_parity)&(tx_dr[7-data_count_reg])	;
								data_count_reg 		<= 	data_count_reg + 1																	;
								baud_count_reg 		<=  0																					;
								state 				<= 	DATA																				;
							end
						end
						else begin
							baud_count_reg 		<= 	baud_count_reg + 1																	;
						end
					end
					PARITY: begin
						tx <= ~cal_parity;
						if (baud_count_reg >= baud_divisor)
						begin
							baud_count_reg 		<=  0		;
							state 				<= STOP		;
						end
						else begin
							baud_count_reg <= baud_count_reg + 1;
						end
					end
					STOP: begin
						tx <= END_BIT;
						if (baud_count_reg >= stop_bit_div)
						begin
							tx_done	<=	1'b1;
							state 	<= 	IDLE;
						end
						else begin
							baud_count_reg <= baud_count_reg + 1;
						end
					end
				endcase
				pre_tx_te <= tx_te;
			end
		end
	end

endmodule
