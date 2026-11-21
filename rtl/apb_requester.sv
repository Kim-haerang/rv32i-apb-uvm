module apb_requester(
  // cpu interface
  input   logic         clk,
  input   logic         rst_n,
  input   logic [31:0]  bus_addr,
  input   logic [31:0]  bus_wdata,
  input   logic         transfer,
  input   logic         bus_we,
  output  logic         ready,
  output  logic [31:0]  bus_rdata,
  
  // apb interface
  input logic PREADY0, // APB RAM
  input logic PREADY1, // GPI
  input logic PREADY2, // GPO
  input logic PREADY3, // GPIO
  input logic PREADY4, // FND
  input logic PREADY5, // UART
  input logic PREADY6,

  input logic [31:0] PRDATA0,
  input logic [31:0] PRDATA1,
  input logic [31:0] PRDATA2,
  input logic [31:0] PRDATA3,
  input logic [31:0] PRDATA4,
  input logic [31:0] PRDATA5,
  input logic [31:0] PRDATA6,

  output logic [31:0] PADDR,
  output logic [31:0] PWDATA,
  output logic        PWRITE,
  output logic        PENABLE,

  output logic        PSEL0,
  output logic        PSEL1,
  output logic        PSEL2,
  output logic        PSEL3,
  output logic        PSEL4,
  output logic        PSEL5,
  output logic        PSEL6
);

  typedef enum logic [1:0] {
    IDLE,
    SETUP,
    ACCESS
  } state_e;

  state_e ns, cs;

  logic addr_dec_en;
  logic [2:0] mux_sel;

  logic [31:0] temp_PADDR, temp_PADDR_next;
  logic [31:0] temp_PWDATA, temp_PWDATA_next;
  logic temp_PWRITE, temp_PWRITE_next;
  
  assign PADDR  = {4'b0000,temp_PADDR[27:0]}; // 왜?
  assign PWDATA = temp_PWDATA;
  assign PWRITE = temp_PWRITE;

  always_ff@(posedge clk) begin
    if(!rst_n) begin
      cs <= IDLE;
      temp_PADDR  <= 32'h0;
      temp_PWDATA <= 32'h0;
      temp_PWRITE <= 1'b0;
    end
    else begin
      cs <= ns;
      temp_PADDR  <= temp_PADDR_next;
      temp_PWDATA <= temp_PWDATA_next;
      temp_PWRITE <= temp_PWRITE_next;
    end
  end

  always_comb begin
    ns            = cs;
    temp_PADDR_next  = temp_PADDR;
    temp_PWDATA_next = temp_PWDATA;
    temp_PWRITE_next = temp_PWRITE;

    addr_dec_en   = 1'b0; 
    PENABLE       = 1'b0; // 1?
    case(cs)
      IDLE : begin
        if(transfer) begin
          temp_PADDR_next  = bus_addr;
          temp_PWDATA_next = bus_wdata;
          temp_PWRITE_next = bus_we;
          ns = SETUP;
        end
      end
      SETUP : begin
        addr_dec_en = 1'b1;
        PENABLE     = 1'b0;
        ns          = ACCESS;
      end
      ACCESS : begin
        addr_dec_en = 1'b1;
        PENABLE     = 1'b1;
        if(ready) ns = IDLE;
      end
    endcase
  end

  address_decoder U_APB_DECODER(
    .enable(addr_dec_en),
    .mux_sel(mux_sel),
    .PADDR(temp_PADDR),
    .*
  );

  apb_mux U_APB_MUX(
    .mux_sel(mux_sel),
    .*
  );


endmodule

module address_decoder(
  input  logic        enable,
  input  logic [31:0] PADDR,
  output logic        PSEL0,
  output logic        PSEL1,
  output logic        PSEL2,
  output logic        PSEL3,
  output logic        PSEL4,
  output logic        PSEL5,
  output logic        PSEL6,
  output logic [2:0]  mux_sel
);

  always_comb begin
    mux_sel = 0; 
    PSEL0 = 0; 
    PSEL1 = 0;
    PSEL2 = 0;
    PSEL3 = 0;
    PSEL4 = 0;
    PSEL5 = 0;
    PSEL6 = 0;
    if(enable) begin 
      case(PADDR[31:28])
        4'b0001 : begin
          PSEL0 = 1;
          mux_sel = 3'b000;
        end
        4'b0010 : begin
          case(PADDR[11:8])
            4'b0000: begin
              PSEL1 = 1'b1;
              mux_sel = 3'b001;
            end
            4'b0001: begin
              PSEL2 = 1'b1;
              mux_sel = 3'b010;
            end
            4'b0010: begin
              PSEL3 = 1'b1;
              mux_sel = 3'b011;
            end
            4'b0011: begin
              PSEL4 = 1'b1;
              mux_sel = 3'b100;
            end
            4'b0100: begin
              PSEL5 = 1'b1;
              mux_sel = 3'b101;
            end
            4'b0101: begin
              PSEL6 = 1'b1;
              mux_sel = 3'b110;
            end
           endcase
        end
      endcase
    end
  end

endmodule

module apb_mux(
  input   logic [ 2:0]  mux_sel,
  input   logic [31:0]  PRDATA0,
  input   logic [31:0]  PRDATA1,
  input   logic [31:0]  PRDATA2,
  input   logic [31:0]  PRDATA3,
  input   logic [31:0]  PRDATA4,
  input   logic [31:0]  PRDATA5,
  input   logic [31:0]  PRDATA6,
  input   logic         PREADY0,
  input   logic         PREADY1,
  input   logic         PREADY2,
  input   logic         PREADY3,
  input   logic         PREADY4,
  input   logic         PREADY5,
  input   logic         PREADY6,
  output  logic [31:0]  bus_rdata,
  output  logic         ready
);
  always_comb begin
      bus_rdata = PRDATA0;
      ready     = PREADY0;
    case(mux_sel)
      3'b000: begin
        bus_rdata = PRDATA0;
        ready     = PREADY0;
      end
      3'b001: begin
        bus_rdata = PRDATA1;
        ready     = PREADY1;
      end
      3'b010: begin
        bus_rdata = PRDATA2;
        ready     = PREADY2;
      end
      3'b011: begin
        bus_rdata = PRDATA3;
        ready     = PREADY3;
      end
      3'b100: begin
        bus_rdata = PRDATA4;
        ready     = PREADY4;
      end
      3'b101: begin
        bus_rdata = PRDATA5;
        ready     = PREADY5;
      end
      3'b110: begin
        bus_rdata = PRDATA6;
        ready     = PREADY6;
      end
    endcase
  end
endmodule
