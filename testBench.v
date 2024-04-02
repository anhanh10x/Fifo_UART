module test;
//input clock source
reg clk;
//setup register
reg [24:0] UART_BR; // Baudrate register
wire [7:0] UART_SR;
//RX
//output RX register
wire [7:0] UART_RX_DR;
//TX
//input pin
reg UART_TX_TE;
reg [7:0] UART_TX_DR;
//output TX pin
wire UART_TX;

UART dut(
	//input clock source
    .clk(clk),
	//setup register
    .UART_BR(UART_BR), // Baudrate register
	.UART_SR(UART_SR),
//RX
	//input pin
	.UART_RX(UART_TX),
	//output RX register
    .UART_RX_DR(UART_RX_DR),
//TX
	//input pin
	.UART_TX_TE(UART_TX_TE),
	.UART_TX_DR(UART_TX_DR),
	//output TX pin
    .UART_TX(UART_TX)
);

always #1 clk=~clk;

initial begin
	clk = 1;
	UART_BR = 25'd19;
	UART_TX_DR = 7'd85;

	#5 UART_TX_TE = 1'b0;
	#5 UART_TX_TE = 1'b1;
	#5 UART_TX_TE = 1'b0;
end

endmodule