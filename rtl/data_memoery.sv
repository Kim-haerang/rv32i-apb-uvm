module data_memory (
    input logic        clk,
    input logic [31:0] daddr,
    input logic [31:0] dwdata,
    input logic        dwe,
    input logic [ 2:0] itype,    // 000 001 010
    output logic [31:0] drdata
  );
    logic [31:0] dmem[0:127];

    always_ff @(posedge clk) begin
        if (dwe) begin
            case (itype)
                3'b000: begin
                    case (daddr[1:0])
                        2'b00: dmem[daddr[8:2]][7:0] <= dwdata[7:0];
                        2'b01: dmem[daddr[8:2]][15:8] <= dwdata[7:0];
                        2'b10: dmem[daddr[8:2]][23:16] <= dwdata[7:0];
                        2'b11: dmem[daddr[8:2]][31:24] <= dwdata[7:0];
                    endcase
                end

                3'b001: begin
                    case (daddr[1])
                        1'b0: dmem[daddr[8:2]][15:0] <= dwdata[15:0];
                        1'b1: dmem[daddr[8:2]][31:16] <= dwdata[15:0];
                    endcase
                end

                3'b010: begin
                    dmem[daddr[8:2]] <= dwdata;
                end

                default: ;
            endcase
        end
    end
    // load 
    // using itype condition 
    logic [31:0] read_word;
    logic [7:0] read_byte;
    logic [15:0] read_half;

    assign read_word = dmem[daddr[31:2]];
    assign read_byte = read_word[8*daddr[1:0] +: 8];
    assign read_half = read_word[16*daddr[1] +: 16];

    always_comb begin
        drdata = 32'b0;
        case (itype)
            3'b000: drdata = {{24{read_byte[7]}}, read_byte}; // LB
            3'b001: drdata = {{16{read_half[15]}}, read_half}; // LH
            3'b010: drdata = read_word;                       // LW
            3'b100: drdata = {24'b0, read_byte};               // LBU
            3'b101: drdata = {16'b0, read_half};               // LHU
            default: drdata = 32'b0;
        endcase
    end
endmodule
