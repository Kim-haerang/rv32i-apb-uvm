module rv32i_top (
    input               clk,
    input               rst,
    input  logic [11:0] sw,
    output logic [11:0] led
);
    logic rst_n;
    assign rst_n = ~rst;

    logic [31:0] instr_code;
    logic [31:0] instr_addr;
    logic [31:0] bus_addr;
    logic [31:0] bus_wdata;
    logic [31:0] bus_rdata;
    logic        bus_we;
    logic        ready;
    logic        transfer;
    logic [ 2:0] itype;

    logic        PREADY0;  // APB RAM
    logic        PREADY1;  // GPI
    logic        PREADY2;  // GPO
    logic        PREADY3;  // GPIO
    logic        PREADY4;  // FND
    logic        PREADY5;  // UART
    logic        PREADY6;

    logic [31:0] PRDATA0;
    logic [31:0] PRDATA1;
    logic [31:0] PRDATA2;
    logic [31:0] PRDATA3;
    logic [31:0] PRDATA4;
    logic [31:0] PRDATA5;
    logic [31:0] PRDATA6;

    logic [31:0] PADDR;
    logic [31:0] PWDATA;
    logic        PWRITE;
    logic        PENABLE;

    logic        PSEL0;
    logic        PSEL1;
    logic        PSEL2;
    logic        PSEL3;
    logic        PSEL4;
    logic        PSEL5;
    logic        PSEL6;

    instruction_rom U_INSTR_ROM (.*);
    rv32i_cpu U_RV32I_CPU (.*);
    // data_memory U_DATA( .* );
    apb_requester U_APB_REQUESTER (.*);

    apb_bram U_APB_BRAM (
        .*,
        .PSEL  (PSEL0),
        .PREADY(PREADY0),
        .PRDATA(PRDATA0)
    );

    apb_gpi U_APB_GPI (
        .*,
        .sw    (sw[7:0]),
        .PSEL  (PSEL1),
        .PREADY(PREADY1),
        .PRDATA(PRDATA1)
    );

    apb_gpo U_APB_GPO (
        .*,
        .led   (led[7:0]),
        .PSEL  (PSEL2),
        .PREADY(PREADY2),
        .PRDATA(PRDATA2)
    );

    wire [7:0] gpio;

    apb_gpio U_APB_GPIO (
        .*,
        .gpio(gpio),
        .PSEL   (PSEL3),
        .PREADY (PREADY3),
        .PRDATA (PRDATA3)
    );

    assign gpio[3:0] = sw[11:8];
    assign led[11:8] = gpio[7:4];
endmodule

module rv32i_cpu (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ready,
    input  logic [31:0] bus_rdata,
    input  logic [31:0] instr_code,
    output logic [31:0] instr_addr,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    output logic [ 2:0] itype,       // instruction type : funct3
    output logic        bus_we,
    output logic        transfer
);

    logic       rf_we;
    logic       pc_en;
    logic       branch;
    logic       jal;
    logic       jalr;
    logic [3:0] alu_control;
    logic       alu_srcsel;
    logic [2:0] rf_srcsel;

    control_unit U_CONTROL_UNIT (.*);

    datapath U_DATAPATH (.*);
endmodule
