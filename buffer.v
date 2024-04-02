module buffer
#(
	parameter		DATA_BIT           				= 8	 ,  // data bits
					DATA_BUFFER_LENGTH_WIDTH        = 8		// buffer length
)
(
	input	  									clk			,
	input										reset_n		,
	input	[DATA_BIT-1:0]  					data		,
	input	[DATA_BUFFER_LENGTH_WIDTH-1:0]  	rdaddress	,
	input	[DATA_BUFFER_LENGTH_WIDTH-1:0]  	wraddress	,
	input	  									wren		,
	output	[DATA_BIT-1:0]  					q
);
    ram
    #(
        .DATA_BIT                   (DATA_BIT),
        .DATA_BUFFER_LENGTH_WIDTH   (DATA_BUFFER_LENGTH_WIDTH)
    ) ram_inst
    (
        .clk                 (clk)          ,
		.reset_n			 (reset_n)		,
        .write_addr          (wraddress)   	,
        .read_addr           (rdaddress)    ,
        .write_en            (wren)     	,
        .written_data        (data) 		,
        .read_data           (q)    
	);

endmodule