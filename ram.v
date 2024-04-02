//================================================================================================
//------------------------------------------module RAM----------------------------------------
//================================================================================================
module ram
#(
    parameter		DATA_BIT           				= 8			,       // data bits
					DATA_BUFFER_LENGTH_WIDTH        = 8				 	// buffer length
)
(
    input                                               clk              , // master clock  
    input                                               reset_n          , // reset_n
    input       [DATA_BUFFER_LENGTH_WIDTH-1:0]          write_addr       , // write address
    input       [DATA_BUFFER_LENGTH_WIDTH-1:0]          read_addr        , // read address
    input                                               write_en         , // write enable
    input       [DATA_BIT-1:0]                          written_data     , // written address
    output reg  [DATA_BIT-1:0]                          read_data          // read data
);

    // Internal register and wire
    reg [DATA_BIT-1:0] RAM_MEM [0:2**DATA_BUFFER_LENGTH_WIDTH-1];

    // FSM Write
    always @(posedge clk) 
    begin
        if (write_en)
        begin
            RAM_MEM[write_addr]     <=     written_data;
        end
    end

    // FSM Read
    always @(posedge clk) 
    begin
        if(~reset_n)
            read_data     <= 0;
        else
            read_data     <=     RAM_MEM[read_addr];
    end

endmodule