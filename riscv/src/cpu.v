
`include "mem_ctrler.v"
`include "inst_fetcher.v"
`include "issuer.v"

// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(input wire clk_in,              // system clock signal
             input wire rst_in,              // reset signal
             input wire rdy_in,              // send signal, pause cpu when low
             input wire[7:0] mem_din,        // data input bus
             output wire[7:0] mem_dout,      // data output bus
             output wire[31:0] mem_a,        // address bus (only 17:0 is used)
             output wire mem_wr,             // write/read signal (1 for write)
             input wire io_buffer_full,      // 1 if uart buffer is full
             output wire[31:0] dbgreg_dout); // cpu register output (debugging demo)

  // implementation goes here

  wire[7:0] data_from_ram_to_mem_ctrler;
  wire rw_select_from_mem_ctrler_to_ram;
  wire[`ADDR_TYPE] addr_from_mem_ctrler_to_ram;
  wire[7:0] data_from_mem_ctrler_to_ram;
  wire[`ADDR_TYPE] addr_from_icache_to_mem_ctrler;
  wire valid_from_icache_to_mem_ctrler;
  wire[`DATA_TYPE] data_from_mem_ctrler_to_icache;
  wire ready_from_mem_ctrler_to_icache;
  wire[`ADDR_TYPE] addr_from_dcache_to_mem_ctrler;
  wire[`DATA_TYPE] data_from_dcache_to_mem_ctrler;
  wire valid_from_dcache_to_mem_ctrler;
  wire rw_flag_from_dcache_to_mem_ctrler;
  wire ready_from_mem_ctrler_to_dcache;
  wire[`DATA_TYPE] data_from_mem_ctrler_to_dcache;

  wire valid_from_inst_fetcher_to_icache;
  wire[`ADDR_TYPE] addr_from_inst_fetcher_to_icache;
  wire ready_from_icache_to_inst_fetcher;
  wire[`DATA_TYPE] data_from_icache_to_inst_fetcher;

  wire ready_from_inst_fetcher_to_issuer;
  wire[`INST_TYPE] inst_from_inst_fetcher_to_issuer;

  reg stall;

  assign data_from_ram_to_mem_ctrler = mem_din;
  assign mem_dout = data_from_mem_ctrler_to_ram;
  assign mem_a = addr_from_mem_ctrler_to_ram;
  assign mem_wr = rw_select_from_mem_ctrler_to_ram;

  mem_ctrler mem_ctrler_0(
               .clk(clk_in),
               .rst(rst_in),
               .rdy(rdy_in),
               .data_from_ram(data_from_ram_to_mem_ctrler),
               .rw_select_to_ram(rw_select_from_mem_ctrler_to_ram),
               .addr_to_ram(addr_from_mem_ctrler_to_ram),
               .data_to_ram(data_from_mem_ctrler_to_ram),

               .addr_from_icache(addr_from_icache_to_mem_ctrler),
               .valid_from_icache(valid_from_icache_to_mem_ctrler),
               .data_to_icache(data_from_mem_ctrler_to_icache),
               .ready_to_icache(ready_from_mem_ctrler_to_icache),

               .addr_from_dcache(addr_from_dcache_to_mem_ctrler),
               .data_from_dcache(data_from_dcache_to_mem_ctrler),
               .valid_from_dcache(valid_from_dcache_to_mem_ctrler),
               .rw_flag_from_dcache(rw_flag_from_dcache_to_mem_ctrler),
               .ready_to_dcache(ready_from_mem_ctrler_to_dcache),
               .data_to_dcache(data_from_mem_ctrler_to_dcache));

  inst_fetcher inst_fetcher_0(
                 .clk(clk_in),
                 .rst(rst_in),
                 .rdy(rdy_in),

                 .stall(stall),

                 .valid_to_mem_ctrler(valid_from_icache_to_mem_ctrler),
                 .addr_to_mem_ctrler(addr_from_icache_to_mem_ctrler),
                 .ready_from_mem_ctrler(ready_from_mem_ctrler_to_icache),
                 .inst_from_mem_ctrler(data_from_mem_ctrler_to_icache),

                 .ready_to_issuer(ready_from_inst_fetcher_to_issuer),
                 .inst_to_issuer(inst_from_inst_fetcher_to_issuer));

  issuer issuer_0(
           .clk(clk_in),
           .rst(rst_in),
           .rdy(rdy_in),

           .ready_from_inst_fetcher(ready_from_inst_fetcher_to_issuer),
           .inst_from_inst_fetcher(inst_from_inst_fetcher_to_issuer)
         );

  // Specifications:
  // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
  // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
  // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
  // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16] == 2'b11)
  // - 0x30000 read: read a byte from input
  // - 0x30000 write: write a byte to output (write 0x00 is ignored)
  // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
  // - 0x30004 write: indicates program stop (will output '\0' through uart tx)

  reg[31:0] cnt;

  initial begin
    cnt = 0;
  end

  always @(posedge clk_in) begin
    if (cnt == 20) begin
      stall <= 1;
      cnt <= 0;
    end else begin
      stall <= 0;
      cnt <= cnt + 1;
    end

    if (rst_in) begin

    end else if (!rdy_in) begin

    end else begin

    end
  end

endmodule
