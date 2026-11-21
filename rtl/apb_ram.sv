module apb_bram(
	input		logic			clk,
	input		logic [ 2:0]	itype,
	input		logic			PSEL,
	input		logic			PENABLE,
	input		logic [31:0]	PADDR,
	input		logic [31:0]	PWDATA,
	input		logic			PWRITE,
	output	    logic			PREADY,
	output	    logic [31:0]	PRDATA
);

	logic [31:0] dmem[0:127];

	assign PREADY	= (PENABLE & PSEL) ? 1'b1:1'b0;


	// store
	always_ff @(posedge clk) begin
		if (PREADY && PWRITE) begin
			case(itype)
                // SB
                3'b000: begin
                    case (PADDR[1:0])
                        2'b00: dmem[PADDR[31:2]][7:0]   <= PWDATA[7:0];
                        2'b01: dmem[PADDR[31:2]][15:8]  <= PWDATA[7:0];
                        2'b10: dmem[PADDR[31:2]][23:16] <= PWDATA[7:0];
                        2'b11: dmem[PADDR[31:2]][31:24] <= PWDATA[7:0];
                    endcase
                end

                // SH
                3'b001: begin
                    case (PADDR[1:0])
                        2'b00: dmem[PADDR[31:2]][15:0]  <= PWDATA[15:0];
                        2'b10: dmem[PADDR[31:2]][31:16] <= PWDATA[15:0];
                    endcase
                end
			    // SW
				3'b010:		dmem[PADDR[31:2]]	<= PWDATA;
				default:	dmem[PADDR[31:2]]	<= dmem[PADDR[31:2]];
			endcase
		end
	end
	
	// load 
    // using itype condition 
    logic [31:0] read_word;
    logic [ 7:0] read_byte;
    logic [15:0] read_half;

    assign read_word = dmem[PADDR[8:2]];
    always_comb begin
        case (PADDR[1:0])
            2'b00:   read_byte = read_word[7:0];
            2'b01:   read_byte = read_word[15:8];
            2'b10:   read_byte = read_word[23:16];
            2'b11:   read_byte = read_word[31:24];
            default: read_byte = 8'b0;
        endcase

        case (PADDR[1])
            1'b0: read_half = read_word[15:0];
            1'b1: read_half = read_word[31:16];
            default: read_half = 16'b0;
        endcase
    end

    always_comb begin
        PRDATA = 32'hz;
        if (PREADY && !PWRITE) begin
            case (itype)
                3'b000:  PRDATA = {{24{read_byte[7]}}, read_byte};  // LB
                3'b001:  PRDATA = {{16{read_half[15]}}, read_half};  // LH
                3'b010:  PRDATA = read_word;  // LW
                3'b100:  PRDATA = {24'b0, read_byte};  // LBU
                3'b101:  PRDATA = {16'b0, read_half};  // LHU
                default: PRDATA = 32'hz;
            endcase
        end
    end
endmodule



