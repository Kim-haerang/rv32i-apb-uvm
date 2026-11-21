
module apb_gpi (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic [31:0] PADDR,
  input  logic [31:0] PWDATA,
  input  logic        PWRITE,
  input  logic [ 7:0] sw,
  output logic        PREADY,
  output logic [31:0] PRDATA
);

  localparam GPI_CTR_ADDR = 8'h00, GPI_IDR_ADDR = 8'h04;

  logic [7:0] GPI_CTR; // 000h
  logic [7:0] GPI_IDR; // 004h

  assign PREADY = (PSEL & PENABLE) ? 1'b1 : 1'b0;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
        GPI_CTR <= 8'h0;
    end else begin
        if (PREADY && PWRITE) begin
            if (PADDR[7:0] == GPI_CTR_ADDR) GPI_CTR <= PWDATA[7:0];
        end
    end
  end

  assign PRDATA = (PADDR[7:0] == GPI_CTR_ADDR) ? {24'h0, GPI_CTR} :
                  (PADDR[7:0] == GPI_IDR_ADDR) ? {24'h0, GPI_IDR} : 32'hx;

  genvar i;
  generate
      for (i = 0; i < 8; i++) begin : gen_gpi_idr
          assign GPI_IDR[i] = GPI_CTR[i] ? sw[i] : 1'bz;
      end
  endgenerate
endmodule

module apb_gpo (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic [31:0] PADDR,
  input  logic [31:0] PWDATA,
  input  logic        PWRITE,
  output logic        PREADY,
  output logic [31:0] PRDATA,
  output logic [ 7:0] led
);

    logic [7:0] GPO_CTR; // 000h
    logic [7:0] GPO_ODR; // 004h


  assign PREADY = PSEL && PENABLE;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
            GPO_CTR <= 8'h0;
            GPO_ODR <= 8'h0;
    end else if (PREADY && PWRITE) begin
      case (PADDR[11:0])
        12'h100: GPO_CTR <= PWDATA[7:0];
        12'h104: GPO_ODR <= PWDATA[7:0];
        default: ;
      endcase
    end
  end

  assign led = GPO_CTR & GPO_ODR;
  assign PRDATA = {24'b0, led};

endmodule

module apb_gpio (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic [31:0] PADDR,
  input  logic [31:0] PWDATA,
  input  logic        PWRITE,
  output logic        PREADY,
  output logic [31:0] PRDATA,
  inout  wire  [ 7:0] gpio
);

    logic [7:0] GPIO_CTR; // 000h
    logic [7:0] GPIO_ODR; // 004h
    logic [7:0] GPIO_IDR; // 008h

  assign PREADY = PSEL && PENABLE;

generate
  for(genvar i=0; i<8; i++) begin : gen_gpio_dir
    assign gpio[i] = GPIO_CTR[i] ? 1'bz : GPIO_ODR[i];
    assign GPIO_IDR[i] = GPIO_CTR[i] ? gpio[i] : 1'b0;
  end
endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      GPIO_CTR <= 8'b0;
      GPIO_ODR <= 8'b0;
    end else if (PREADY && PWRITE) begin
      case (PADDR[11:0])
        12'h200: GPIO_CTR <= PWDATA[7:0];
        12'h204: GPIO_ODR <= PWDATA[7:0];
        default: ;
      endcase
    end
  end

  always_comb begin
    case (PADDR[11:0])
      12'h200: PRDATA = {24'b0, GPIO_CTR};
      12'h204: PRDATA = {24'b0, GPIO_ODR};
      12'h208: PRDATA = {24'b0, GPIO_IDR};
      default: PRDATA = 32'b0;
    endcase
  end

endmodule
