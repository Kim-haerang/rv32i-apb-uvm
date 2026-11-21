`include "uvm_macros.svh"
import uvm_pkg::*;

interface gpio_cpu_if(
	input logic clk
);

	logic rst_n;
	logic transfer;
	logic bus_we;
	logic [2:0] itype;
	logic [31:0] bus_addr;
	logic [31:0] bus_wdata;
	logic [31:0] bus_rdata;
	logic ready;

	clocking mon_cb @(posedge clk);
		default input #1step;
		input rst_n;
		input transfer;
		input bus_we;
		input itype;
		input bus_addr;
		input bus_wdata;
		input bus_rdata;
		input ready;
	endclocking

endinterface

interface gpio_apb_if(
	input logic clk
);

	logic rst_n;
	logic [2:0] itype;
	logic PENABLE;
	logic PWRITE;
	logic [6:0] PSEL; // slaves vector, number of slaves = 7
	logic [6:0] PREADY; // slaves vector, number of slaves = 7
	logic [31:0] PRDATA [0:6]; // slaves vector, number of slaves = 7
	logic [31:0] PADDR;
	logic [31:0] PWDATA;

	clocking mon_cb @(posedge clk);
		default input #1step;
		input rst_n;
		input itype;
		input PSEL;
		input PENABLE;
		input PADDR;
		input PWDATA;
		input PRDATA;
		input PWRITE;
		input PREADY;
	endclocking

	property p_one_slave_or_none;
		@(posedge clk) disable iff (!rst_n)
			$onehot0(PSEL);
	endproperty

	property p_setup_to_access;
		@(posedge clk) disable iff (!rst_n)
			(|PSEL) && !PENABLE |=> (|PSEL) && PENABLE;
	endproperty

	property p_enable_requires_select;
		@(posedge clk) disable iff (!rst_n)
			PENABLE |-> (|PSEL);
	endproperty

	property p_control_stable_during_wait;
		@(posedge clk) disable iff (!rst_n)
			(|PSEL) && PENABLE && !(|(PSEL & PREADY)) |=> $stable({PSEL, PADDR, PWDATA, PWRITE, itype});
	endproperty

	a_one_slave_or_none: assert property(p_one_slave_or_none);
	a_setup_to_access: assert property(p_setup_to_access);
	a_enable_requires_select: assert property(p_enable_requires_select);
	a_control_stalbe_during_wait: assert property(p_control_stable_during_wait);

endinterface

interface gpio_pin_if(
	input logic clk
);
	logic rst;
	logic [11:0] sw;
	logic [11:0] led;

	clocking mon_cb @(posedge clk);
		default input #1step;
		input rst;
		input sw;
		input led;
	endclocking

endinterface

class gpio_cpu_item extends uvm_sequence_item;
	logic [31:0] addr;
	logic [31:0] wdata;
	logic [31:0] rdata;
	logic [2:0] itype;
	logic write;

	`uvm_object_utils_begin(gpio_cpu_item)
		`uvm_field_int(addr, UVM_DEFAULT)
		`uvm_field_int(rdata, UVM_DEFAULT)
		`uvm_field_int(wdata, UVM_DEFAULT)
		`uvm_field_int(itype, UVM_DEFAULT)
		`uvm_field_int(write, UVM_DEFAULT)
	`uvm_object_utils_end

	function new(string name = "gpio_cpu_item");
		super.new(name);
	endfunction

	virtual function string cvt2str();
		return $sformatf("CPU write = %0b, itype = %03b, addr = %08h, wdata = %08h, rdata = %08h", write, itype, addr, wdata, rdata);
	endfunction

endclass

class gpio_apb_item extends uvm_sequence_item;
	logic [6:0] psel;
	logic [2:0] itype;
	logic [31:0] addr;
	logic [31:0] wdata;
	logic [31:0] rdata;
	logic write;
	int slave_id;

	`uvm_object_utils_begin(gpio_apb_item)
		`uvm_field_int(psel, UVM_DEFAULT)
		`uvm_field_int(addr, UVM_DEFAULT)
		`uvm_field_int(wdata, UVM_DEFAULT)
		`uvm_field_int(rdata, UVM_DEFAULT)
		`uvm_field_int(itype, UVM_DEFAULT)
		`uvm_field_int(write, UVM_DEFAULT)
		`uvm_field_int(slave_id, UVM_DEFAULT)
	`uvm_object_utils_end

	function new(string name = "gpio_uvm_apb_item");
		super.new(name);
		slave_id = -1;
	endfunction

	virtual function string cvt2str();
		return $sformatf("APB slave = %0d, psel = %07b, write = %0b, itype = %03b, addr = %08h, wdata = %08h, rdata = %08h", slave_id, psel, write, itype, addr, wdata, rdata);
	endfunction

endclass

class gpio_cpu_monitor extends uvm_monitor;
	`uvm_component_utils(gpio_cpu_monitor)

	virtual gpio_cpu_if gc_if;
	uvm_analysis_port #(gpio_cpu_item) analysis_port;

	bit request_pending;
	gpio_cpu_item gc_item;

	function new(string name = "gpio_cpu_monitor", uvm_component p = null);
		super.new(name, p);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db #(virtual gpio_cpu_if)::get(this, "", "gc_if", gc_if))
			`uvm_fatal("CPU_MON", "unable to access CPU interface")
		analysis_port = new("analysis_port", this);
		request_pending = 1'b0;
	endfunction

	virtual task run_phase(uvm_phase phase);
		forever begin
			@(gc_if.mon_cb);
			if(!gc_if.mon_cb.rst_n) begin
				request_pending = 1'b0;
				gc_item= null;
			end else begin
				if(!request_pending && gc_if.mon_cb.transfer) begin
					gc_item = gpio_cpu_item::type_id::create("gc_item", this);
					gc_item.addr = gc_if.mon_cb.bus_addr;
					gc_item.wdata = gc_if.mon_cb.bus_wdata;
					gc_item.write = gc_if.mon_cb.bus_we;
					gc_item.itype = gc_if.mon_cb.itype;
					request_pending = 1'b1;
				end

				if(request_pending && gc_if.mon_cb.ready) begin
					gc_item.rdata = gc_if.mon_cb.bus_rdata;
					`uvm_info("CPU_MON", gc_item.cvt2str(), UVM_HIGH)
					analysis_port.write(gc_item);
					gc_item = null;
					request_pending = 1'b0;
				end
			end
		end
	endtask

endclass

class gpio_apb_monitor extends uvm_monitor;
	`uvm_component_utils(gpio_apb_monitor)

	virtual gpio_apb_if ga_if;
	uvm_analysis_port #(gpio_apb_item) analysis_port;

	function new(string name = "gpio_apb_monitor", uvm_component p = null);
		super.new(name, p);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db #(virtual gpio_apb_if)::get(this, "", "ga_if", ga_if))
			`uvm_fatal("APB_MON", "unable to access APB interface")
		analysis_port = new("analysis_port", this);
	endfunction

	virtual function int selected_slave(logic [6:0] psel);
		case(psel)
			7'b0000001: return 0;
			7'b0000010: return 1;
			7'b0000100: return 2;
			7'b0001000: return 3;
			7'b0010000: return 4;
			7'b0100000: return 5;
			7'b1000000: return 6;
			default: return -1;
		endcase
	endfunction

	virtual task run_phase(uvm_phase phase);
		gpio_apb_item ga_item;
		int slave_id;

		forever begin
			@(ga_if.mon_cb);
			if(ga_if.mon_cb.rst_n && ga_if.mon_cb.PENABLE) begin
				slave_id = selected_slave(ga_if.mon_cb.PSEL);

				if(slave_id < 0) begin
					if(|ga_if.mon_cb.PSEL)
						`uvm_error("APB_MON", $sformatf("invalid PSEL value %07b", ga_if.mon_cb.PSEL))
				end else if(ga_if.mon_cb.PREADY[slave_id] === 1'b1) begin
					ga_item = gpio_apb_item::type_id::create("observed_item", this);
					ga_item.psel = ga_if.mon_cb.PSEL;
					ga_item.slave_id = slave_id;
					ga_item.addr = ga_if.mon_cb.PADDR;
					ga_item.wdata = ga_if.mon_cb.PWDATA;
					ga_item.write = ga_if.mon_cb.PWRITE;
					ga_item.itype = ga_if.mon_cb.itype;
					ga_item.rdata = ga_if.mon_cb.PRDATA[slave_id];
					`uvm_info("APB_MON", ga_item.cvt2str(), UVM_HIGH)
					analysis_port.write(ga_item);
				end
			end
		end
	endtask
endclass

class gpio_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(gpio_scoreboard)

	uvm_tlm_analysis_fifo #(gpio_cpu_item) cpu_fifo;
	uvm_tlm_analysis_fifo #(gpio_apb_item) apb_fifo;
	virtual gpio_pin_if gp_if;

	logic [7:0] gpi_ctr;
	logic [7:0] gpo_ctr;
	logic [7:0] gpo_odr;
	logic [7:0] gpio_ctr;
	logic [7:0] gpio_odr;

	int unsigned expected_transactions = 8;
	int unsigned pair_count;
	int unsigned pass_count;
	int unsigned fail_count;

	function new(string name = "gpio_scoreboard", uvm_component p = null);
		super.new(name, p);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		cpu_fifo = new("cpu_fifo", this);
		apb_fifo = new("apb_fifo", this);

		if(!uvm_config_db #(virtual gpio_pin_if)::get(this, "", "gp_if", gp_if))
			`uvm_fatal("GPIO_SCB", "unable to access GPIO pin interface")
		void'(uvm_config_db #(int unsigned)::get(this, "", "expected_transactions", expected_transactions));

		gpi_ctr = 8'h00;
		gpo_ctr = 8'h00;
		gpo_odr = 8'h00;
		gpio_ctr = 8'h00;
		gpio_odr = 8'h00;
		pair_count = 0;
		pass_count = 0;
		fail_count = 0;
	endfunction

	virtual task run_phase(uvm_phase phase);
		gpio_cpu_item gc_item;
		gpio_apb_item ga_item;

		forever begin
			cpu_fifo.get(gc_item);
			apb_fifo.get(ga_item);
			compare_pair(gc_item, ga_item);
		end
	endtask

	virtual function int expected_slave(logic [31:0] cpu_addr);
		case(cpu_addr[31:28])
			4'h1: return 0;
			4'h2: begin
				case(cpu_addr[11:8])
					4'h0: return 1;
					4'h1: return 2;
					4'h2: return 3;
					4'h3: return 4;
					4'h4: return 5;
					4'h5: return 6;
					default: return -1;
				endcase
			end
			default: return -1;
		endcase
	endfunction

	virtual function void compare_pair(gpio_cpu_item gc_item, gpio_apb_item ga_item);
		logic [31:0] expected_paddr;
		logic [31:0] expected_rdata;
		int expected_slave_id;
		bit pair_ok;

		pair_ok = 1;
		expected_paddr = {4'b0000, gc_item.addr[27:0]};
		expected_slave_id = expected_slave(gc_item.addr);

		if(ga_item.slave_id != expected_slave_id) begin
			pair_ok = 0;
			`uvm_error("GPIO_SCB", $sformatf("slave mismatch: CPU addr = %08h, expected = %0d, actual = %0d", gc_item.addr, expected_slave_id, ga_item.slave_id))
		end

		if(ga_item.addr !== expected_paddr) begin
			pair_ok = 0;
			`uvm_error("GPIO_SCB", $sformatf("PADDR mismatch: expected = %08h, actual = %08h", expected_paddr, ga_item.addr))
		end

		if(ga_item.write !== gc_item.write) begin
			pair_ok = 1'b0;
			`uvm_error("GPIO_SCB", $sformatf("PWRITE mismatch: CPU = %0b, APB = %0b", gc_item.write, ga_item.write))
		end

		if(ga_item.itype !== gc_item.itype) begin
			pair_ok = 1'b0;
			`uvm_error("GPIO_SCB", $sformatf("PWRITE mismatch: CPU = %0b, APB = %0b", gc_item.write, ga_item.write))
		end

		if(ga_item.wdata !== gc_item.wdata) begin
			pair_ok = 1'b0;
			`uvm_error("GPIO_SCB", $sformatf("PWDATA mismatch: CPU = %08h, APB = %08h", gc_item.wdata, ga_item.wdata))
		end

		if(!gc_item.write && gc_item.rdata !== ga_item.rdata) begin
			pair_ok = 1'b0;
			`uvm_error("GPIO_SCB", $sformatf("read path mismatch: APB = %08h, CPU = %08h", ga_item.rdata, gc_item.rdata))
		end

		if(!check_program_order(ga_item, pair_count)) pair_ok = 1'b0;

		expected_rdata = 32'hxxxx_xxxx;
		case(ga_item.slave_id)
			1: begin
				if(ga_item.write) begin
					if(ga_item.addr[7:0] == 8'h00) gpi_ctr = ga_item.wdata[7:0];
				end else begin
					expected_rdata = predict_gpi_read(ga_item.addr);
				end
			end
			2: begin
				if(ga_item.write) begin
					case(ga_item.addr[11:0])
						12'h100: gpo_ctr = ga_item.wdata[7:0];
						12'h104: gpo_odr = ga_item.wdata[7:0];
						default: ;
					endcase
				end else begin
					expected_rdata = {24'h000000,(gpo_ctr&gpo_odr)};
				end
			end
			3: begin
				if(ga_item.write) begin
					case(ga_item.addr[11:0])
						12'h200: gpio_ctr = ga_item.wdata[7:0];
						12'h204: gpio_odr = ga_item.wdata[7:0];
						default: ;
					endcase
				end else begin
					expected_rdata = predict_gpio_read(ga_item.addr);
				end
			end
			default: ;
		endcase

		if(!ga_item.write && (ga_item.slave_id inside {1,2,3})) begin
			if(ga_item.rdata !== expected_rdata) begin
				pair_ok = 1'b0;
				`uvm_error("GPIO_SCB", $sformatf("peripheral read mismatch: slave = %0d, addr = %08h, expected = %08h, actual = %08h", ga_item.slave_id, ga_item.addr, expected_rdata, ga_item.rdata))
			end
		end

		pair_count++;
		if(pair_ok) begin
			pass_count++;
			`uvm_info("GPIO_SCB", $sformatf("transaction %0d passed: %s", pair_count, ga_item.cvt2str()), UVM_HIGH)
		end else begin
			fail_count++;
		end
	endfunction

	virtual function bit check_program_order(gpio_apb_item ga_item, int unsigned index);
		logic [31:0] expected_addr;
		logic [31:0] expected_wdata;
		logic expected_write;
		int expected_slave_id;
		bit result;

		result = 1'b1;
		expected_slave_id = -1;
		expected_addr = 32'h0000_0000;
		expected_write = 1'b0;
		expected_wdata = 32'h0000_0000;

		case(index)
			0: begin
				expected_slave_id = 1;
				expected_addr = 32'h0000_0000;
				expected_write = 1'b1;
				expected_wdata = 32'h0000_00ff;
			end
			1: begin
				expected_slave_id = 1;
				expected_addr = 32'h0000_0000;
				expected_write = 1'b0;
			end
			2: begin
				expected_slave_id = 2;
				expected_addr = 32'h0000_0100;
				expected_write = 1'b1;
				expected_wdata = 32'h0000_000f;
			end
			3: begin
				expected_slave_id = 2;
				expected_addr = 32'h0000_0104;
				expected_write = 1'b1;
				expected_wdata = 32'h0000_0005;
			end
			4: begin
				expected_slave_id = 2;
				expected_addr = 32'h0000_0104;
				expected_write = 1'b0;
			end
			5: begin
				expected_slave_id = 3;
				expected_addr = 32'h0000_0200;
				expected_write = 1'b1;
				expected_wdata = 32'h0000_000f;
			end
			6: begin
				expected_slave_id = 3;
				expected_addr = 32'h0000_0204;
				expected_write = 1'b1;
				expected_wdata = 32'h0000_000a;
			end
			7: begin
				expected_slave_id = 3;
				expected_addr = 32'h0000_0208;
				expected_write = 1'b0;
			end
			default: begin
				`uvm_error("GPIO_SCB", $sformatf("unexpected extra APB transaction at index %0d", index))
				return 1'b0;
			end
		endcase

		if(ga_item.slave_id != expected_slave_id || ga_item.addr !== expected_addr || ga_item.write !== expected_write) begin
			`uvm_error("GPIO_SCB", $sformatf("program order mismatch at index %0d", index))
			result = 1'b0;
		end

		if(expected_write && ga_item.wdata !== expected_wdata) begin
			`uvm_error("GPIO_SCB", $sformatf("program write data mismatch at index %0d: expected = %08h, actual = %08h", index, expected_wdata, ga_item.wdata))
			result = 1'b0;
		end

		return result;
	endfunction

	virtual function logic [31:0] predict_gpi_read(logic [31:0] addr);
		logic [7:0] expected_idr;
		for (int i = 0; i < 8; i++) expected_idr[i] = gpi_ctr[i] ? gp_if.sw[i] : 1'bz;

		case(addr[7:0])
			8'h00: return {24'h000000, gpi_ctr};
			8'h04: return {24'h000000, expected_idr};
			default: return 32'hxxxx_xxxx;
		endcase
	endfunction

	virtual function logic [31:0] predict_gpio_read(logic [31:0] addr);
		logic [7:0] expected_pin;
		logic [7:0] expected_idr;

		for(int i=0; i<8; i++) begin
			if(gpio_ctr[i]) expected_pin[i] = gpio_odr[i];
			else if(i>=4) expected_pin[i] = gp_if.sw[i+4];
			else expected_pin[i] = 1'bz;

			expected_idr[i] = expected_pin[i] & ~gpio_ctr[i];
		end

		case(addr[11:0])
			12'h200: return {24'h000000, gpio_ctr};
			12'h204: return {24'h000000, gpio_odr};
			12'h208: return {24'h000000, expected_idr};
			default: return 32'h0000_0000;
		endcase
	endfunction

	virtual function void check_final_outputs();
		logic [11:0] expected_led;

		expected_led[7:0] = gpo_ctr & gpo_odr;
		for(int i=0; i<4; i++) expected_led[i+8] = gpio_ctr[i] ? gpio_odr[i] : 1'bz;

		if(gp_if.led !== expected_led) begin
			fail_count++;
			`uvm_error("GPIO_SCB", $sformatf("LED mismatch: expected = %03h, actual = %03h", expected_led, gp_if.led))
		end else begin
			`uvm_info("GPIO_SCB", $sformatf("LED match: expected = %03h, actual = %03h", expected_led, gp_if.led), UVM_HIGH)
		end
	endfunction

	virtual function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		`uvm_info("GPIO_SCB", $sformatf("RESULT : paired = %0d, passed = %0d, failed = %0d", pair_count, pass_count, fail_count), UVM_NONE)

		if(pair_count != expected_transactions)
			`uvm_error("GPIO_SCB", $sformatf("Transaction mismatch: expected = %0d, observed = %0d", expected_transactions, pair_count))

		if(fail_count != 0)
			`uvm_error("GPIO_SCB", "RV32I GPIO integration test failed")
	endfunction
endclass

class gpio_coverage extends uvm_subscriber #(gpio_apb_item);
	`uvm_component_utils(gpio_coverage)

	gpio_apb_item ga_item;

	covergroup gpio_cg;
		option.per_instance = 1;
		cp_slave: coverpoint ga_item.slave_id {
			bins gpi = {1};
			bins gpo = {2};
			bins gpio = {3};
			ignore_bins unused = {0,4,5,6};
		}
		cp_write: coverpoint ga_item.write;
		cp_offset: coverpoint ga_item.addr[11:0] {
			bins gpi_ctr = {12'h000};
			bins gpi_idr = {12'h004};
			bins gpo_ctr = {12'h100};
			bins gpo_odr = {12'h104};
			bins gpio_ctr = {12'h200};
			bins gpio_odr = {12'h204};
			bins gpio_idr = {12'h208};
		}
		slave_x_dir: cross cp_slave, cp_write;
	endgroup

	function new(string name = "gpio_coverage", uvm_component p = null);
		super.new(name, p);
		gpio_cg = new();
	endfunction

	virtual function void write(gpio_apb_item t);
		ga_item = t;
		gpio_cg.sample(); // record coverpoint value to coverage db when function call
	endfunction
endclass

class gpio_environment extends uvm_env;
	`uvm_component_utils(gpio_environment)

	gpio_cpu_monitor gpio_cpu_mon;
	gpio_apb_monitor gpio_apb_mon;
	gpio_scoreboard gpio_scb;
	gpio_coverage gpio_cov;

	function new(string name = "gpio_env", uvm_component p = null);
		super.new(name, p);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		gpio_cpu_mon = gpio_cpu_monitor::type_id::create("gpio_cpu_mon", this);
		gpio_apb_mon = gpio_apb_monitor::type_id::create("gpio_apb_mon", this);
		gpio_scb = gpio_scoreboard::type_id::create("gpio_scb", this);
		gpio_cov = gpio_coverage::type_id::create("gpio_cov", this);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		gpio_cpu_mon.analysis_port.connect(gpio_scb.cpu_fifo.analysis_export);
		gpio_apb_mon.analysis_port.connect(gpio_scb.apb_fifo.analysis_export);
		gpio_apb_mon.analysis_port.connect(gpio_cov.analysis_export);
	endfunction
endclass

class rv32i_gpio_test extends uvm_test;
	`uvm_component_utils(rv32i_gpio_test)

	gpio_environment gpio_env;
	virtual gpio_cpu_if gc_if;

	function new(string name = "rv32i_gpio_test", uvm_component p = null);
		super.new(name, p);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db #(virtual gpio_cpu_if)::get(this, "", "gc_if", gc_if))
			`uvm_fatal("GPIO_TEST", "unable to access CPU interface")

		uvm_config_db #(int unsigned)::set(this, "gpio_env.gpio_scb", "expected_transactions", 8);
		gpio_env = gpio_environment::type_id::create("gpio_env", this);
	endfunction

	virtual task run_phase(uvm_phase phase);
		int unsigned timeout_cycles;

		phase.raise_objection(this);
		wait(gc_if.rst_n === 1'b1);

		timeout_cycles = 0;
		while ((gpio_env.gpio_scb.pair_count < gpio_env.gpio_scb.expected_transactions) && (timeout_cycles < 1500)) begin
			@(gc_if.mon_cb);
			timeout_cycles++;
		end

		if(gpio_env.gpio_scb.pair_count < gpio_env.gpio_scb.expected_transactions)
			`uvm_error("GPIO_TEST", $sformatf("timeout: completed %0d/%0d transactions", gpio_env.gpio_scb.pair_count, gpio_env.gpio_scb.expected_transactions))

		repeat(5) @(gc_if.mon_cb);
		gpio_env.gpio_scb.check_final_outputs();
		phase.drop_objection(this);
	endtask
endclass

module tb_rv32i_gpio_uvm();
	logic clk = 0;
	logic rst = 1;
	logic [11:0] sw;
	logic [11:0] led;

	gpio_cpu_if gc_if(clk);
	gpio_apb_if ga_if(clk);
	gpio_pin_if gp_if(clk);

	rv32i_top dut(
		.clk(clk),
		.rst(rst),
		.sw(sw),
		.led(led)
	);

  assign gc_if.rst_n     = dut.rst_n;
  assign gc_if.transfer  = dut.transfer;
  assign gc_if.bus_we    = dut.bus_we;
  assign gc_if.itype     = dut.itype;
  assign gc_if.bus_addr  = dut.bus_addr;
  assign gc_if.bus_wdata = dut.bus_wdata;
  assign gc_if.ready     = dut.ready;
  assign gc_if.bus_rdata = dut.bus_rdata;

  assign ga_if.rst_n   = dut.rst_n;
  assign ga_if.PSEL    = {
    dut.PSEL6, dut.PSEL5, dut.PSEL4, dut.PSEL3, dut.PSEL2, dut.PSEL1, dut.PSEL0
  };
  assign ga_if.PENABLE = dut.PENABLE;
  assign ga_if.PADDR   = dut.PADDR;
  assign ga_if.PWDATA  = dut.PWDATA;
  assign ga_if.PWRITE  = dut.PWRITE;
  assign ga_if.itype   = dut.itype;
  assign ga_if.PREADY  = {
    dut.PREADY6, dut.PREADY5, dut.PREADY4, dut.PREADY3,
    dut.PREADY2, dut.PREADY1, dut.PREADY0
  };
  assign ga_if.PRDATA[0] = dut.PRDATA0;
  assign ga_if.PRDATA[1] = dut.PRDATA1;
  assign ga_if.PRDATA[2] = dut.PRDATA2;
  assign ga_if.PRDATA[3] = dut.PRDATA3;
  assign ga_if.PRDATA[4] = dut.PRDATA4;
  assign ga_if.PRDATA[5] = dut.PRDATA5;
  assign ga_if.PRDATA[6] = dut.PRDATA6;

  assign gp_if.rst = rst;
  assign gp_if.sw  = sw;
  assign gp_if.led = led;

	always #5 clk = ~clk;

`ifdef VCS
	initial begin
		$fsdbDumpfile("wave.fsdb");
		$fsdbDumpvars(0, tb_rv32i_gpio_uvm);
	end
`endif

	initial begin
		sw = 12'ha5a;
		repeat (4) @(posedge clk);
		@(negedge clk);
		rst = 1'b0;
	end

	initial begin
		uvm_config_db #(virtual gpio_cpu_if)::set(null, "uvm_test_top*", "gc_if", gc_if);
		uvm_config_db #(virtual gpio_apb_if)::set(null, "uvm_test_top.gpio_env.gpio_apb_mon", "ga_if", ga_if);
		uvm_config_db #(virtual gpio_pin_if)::set(null, "uvm_test_top.gpio_env.gpio_scb", "gp_if", gp_if);
		run_test("rv32i_gpio_test");
	end

endmodule
