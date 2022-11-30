
`include "mem_ctrler.v"
`include "inst_fetcher.v"
`include "issuer.v"
`include "rs_station.v"
`include "new_ls_buffer.v"
`include "ro_buffer.v"
`include "reg_file.v"
`include "lsb_bus.v"
`include "rss_bus.v"
`include "rob_bus.v"
`include "br_predictor.v"

// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(input wire clk_in,              // system clock signal
             input wire rst_in,              // reset signal
             input wire rdy_in,              // send signal, pause cpu when low
             input wire[7:0] mem_din,        // data input bus
             output wire[7:0] mem_dout,      // data output bus
             output wire[31:0] mem_a,        // address bus (only 17:0 is used)
             output wire mem_wr,             // write/read signal (1 for write)
             input wire is_io_buffer_full,      // 1 if uart buffer is full
             output wire[31:0] dbgreg_dout); // cpu register output (debugging demo)

  // implementation goes here

  wire rst = rst_in | ~rdy_in;

  // mem ctrler related
  wire[7:0] data_from_ram_to_mem_ctrler;
  wire rw_select_from_mem_ctrler_to_ram;
  wire[`ADDR_TYPE] addr_from_mem_ctrler_to_ram;
  wire[7:0] data_from_mem_ctrler_to_ram;
  wire[`ADDR_TYPE] addr_from_icache_to_mem_ctrler;
  wire valid_from_icache_to_mem_ctrler;
  wire[`CACHE_LINE_TYPE] data_from_mem_ctrler_to_icache;
  wire ready_from_mem_ctrler_to_icache;
  wire[`ADDR_TYPE] addr_from_dcache_to_mem_ctrler;
  wire[`CACHE_LINE_TYPE] data_from_dcache_to_mem_ctrler;
  wire valid_from_dcache_to_mem_ctrler;
  wire rw_flag_from_dcache_to_mem_ctrler;
  wire ready_from_mem_ctrler_to_dcache;
  wire[`CACHE_LINE_TYPE] data_from_mem_ctrler_to_dcache;

  wire valid_from_io_to_mem_ctrler;
  wire[`ADDR_TYPE] addr_from_io_to_mem_ctrler;
  wire[`BYTE_TYPE] data_from_io_to_mem_ctrler;
  wire rw_flag_from_io_to_mem_ctrler;
  wire ready_from_mem_ctrler_to_io;
  wire[`BYTE_TYPE] data_from_mem_ctrler_to_io;

  // full related
  wire is_ls_buffer_full;
  wire is_rs_station_full;
  wire is_ro_buffer_full;
  wire is_any_full = is_ls_buffer_full | is_rs_station_full | is_ro_buffer_full;

  // connection between ram and mem ctrler
  assign data_from_ram_to_mem_ctrler = mem_din;
  assign mem_dout = data_from_mem_ctrler_to_ram;
  assign mem_a = addr_from_mem_ctrler_to_ram;
  assign mem_wr = rw_select_from_mem_ctrler_to_ram;

  mem_ctrler mem_ctrler_0(
               .clk(clk_in),
               .rst(rst),
               .rdy(rdy_in),

               .is_io_buffer_full(is_io_buffer_full),

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
               .data_to_dcache(data_from_mem_ctrler_to_dcache),


               .addr_from_io(addr_from_io_to_mem_ctrler),
               .data_from_io(data_from_io_to_mem_ctrler),
               .valid_from_io(valid_from_io_to_mem_ctrler),
               .rw_flag_from_io(rw_flag_from_io_to_mem_ctrler),
               .ready_to_io(ready_from_mem_ctrler_to_io),
               .data_to_io(data_from_mem_ctrler_to_io)
             );

  wire valid_from_rob_bus_to_br_predictor;
  wire[`BH_TABLE_ID_TYPE] pc_from_rob_bus_to_br_predictor;
  wire is_taken_from_rob_bus_to_br_predictor;
  wire[`INST_TYPE] inst_from_inst_fetcher_to_br_predictor;
  wire[`REG_TYPE] pc_from_inst_fetcher_to_br_predictor;
  wire[`REG_TYPE]next_pc_from_br_predictor_to_inst_fetcher;

  br_predictor br_predictor_0(
                 .clk(clk_in),
                 .rst(rst),
                 .rdy(rdy_in),

                 // ro_buffer
                 .valid_from_rob_bus(valid_from_rob_bus_to_br_predictor),
                 .pc_from_rob_bus(pc_from_rob_bus_to_br_predictor),
                 .is_taken_from_rob_bus(is_taken_from_rob_bus_to_br_predictor),

                 // for inst_fetcher
                 .inst_from_inst_fetcher(inst_from_inst_fetcher_to_br_predictor),
                 .pc_from_inst_fetcher(pc_from_inst_fetcher_to_br_predictor),
                 .next_pc_to_inst_fetcher(next_pc_from_br_predictor_to_inst_fetcher));

  // inst fetcher related
  wire valid_from_inst_fetcher_to_icache;
  wire[`ADDR_TYPE] addr_from_inst_fetcher_to_icache;
  wire ready_from_icache_to_inst_fetcher;
  wire[`REG_TYPE] data_from_icache_to_inst_fetcher;
  wire ready_from_inst_fetcher_to_issuer;
  wire[`INST_TYPE] inst_from_inst_fetcher_to_issuer;
  wire[`REG_TYPE] pc_from_inst_fetcher_to_issuer;
  wire[`REG_TYPE] next_pc_from_inst_fetcher_to_issuer;

  wire reset_from_rob_bus_to_inst_fetcher;
  wire[`REG_TYPE] next_pc_from_rob_bus_to_inst_fetcher;

  inst_fetcher inst_fetcher_0(
                 .clk(clk_in),
                 .rst(rst),
                 .rdy(rdy_in),

                 .is_any_full(is_any_full),

                 .valid_to_mem_ctrler(valid_from_icache_to_mem_ctrler),
                 .addr_to_mem_ctrler(addr_from_icache_to_mem_ctrler),
                 .ready_from_mem_ctrler(ready_from_mem_ctrler_to_icache),
                 .cache_line_from_mem_ctrler(data_from_mem_ctrler_to_icache),

                 .ready_to_issuer(ready_from_inst_fetcher_to_issuer),
                 .pc_to_issuer(pc_from_inst_fetcher_to_issuer),
                 .next_pc_to_issuer(next_pc_from_inst_fetcher_to_issuer),
                 .inst_to_issuer(inst_from_inst_fetcher_to_issuer),

                 .inst_to_br_predictor(inst_from_inst_fetcher_to_br_predictor),
                 .pc_to_br_predictor(pc_from_inst_fetcher_to_br_predictor),
                 .next_pc_from_br_predictor(next_pc_from_br_predictor_to_inst_fetcher),

                 .reset_from_rob_bus(reset_from_rob_bus_to_inst_fetcher),
                 .next_pc_from_rob_bus(next_pc_from_rob_bus_to_inst_fetcher)
               );

  wire[`REG_ID_TYPE] rs_from_issuer_to_reg_file;
  wire[`REG_TYPE] vj_from_reg_file_to_issuer;
  wire[`RO_BUFFER_ID_TYPE] qj_from_reg_file_to_issuer;
  wire[`REG_ID_TYPE] rt_from_issuer_to_reg_file;
  wire[`REG_TYPE] vk_from_reg_file_to_issuer;
  wire[`RO_BUFFER_ID_TYPE] qk_from_reg_file_to_issuer;

  wire[`REG_ID_TYPE] rd_from_issuer_to_reg_file;
  wire[`RO_BUFFER_ID_TYPE] dest_from_issuer_to_reg_file;

  wire[`RO_BUFFER_ID_TYPE] dest_from_issuer_to_rs_station;
  wire[`OP_TYPE] op_from_issuer_to_rs_station;
  wire[`RO_BUFFER_ID_TYPE] qj_from_issuer_to_rs_station;
  wire[`RO_BUFFER_ID_TYPE] qk_from_issuer_to_rs_station;
  wire[`REG_TYPE] vj_from_issuer_to_rs_station;
  wire[`REG_TYPE] vk_from_issuer_to_rs_station;
  wire[`IMM_TYPE] imm_from_issuer_to_rs_station;
  wire[`REG_TYPE] pc_from_issuer_to_rs_station;

  wire[`RO_BUFFER_ID_TYPE] qj_from_issuer_to_ro_buffer;
  wire[`RO_BUFFER_ID_TYPE] qk_from_issuer_to_ro_buffer;
  wire valid_of_vj_from_ro_buffer_to_issuer;
  wire[`REG_TYPE] vj_from_ro_buffer_to_issuer;
  wire valid_of_vk_from_ro_buffer_to_issuer;
  wire[`REG_TYPE] vk_from_ro_buffer_to_issuer;

  wire[`RO_BUFFER_ID_TYPE] dest_from_ro_buffer_to_issuer;
  wire valid_from_issuer_to_ro_buffer;
  wire[`ISSUER_TO_ROB_SIGNAL_TYPE] signal_from_issuer_to_ro_buffer;
  wire[`REG_ID_TYPE] rd_from_issuer_to_ro_buffer; // for normal instruction only
  wire[`REG_TYPE] pc_from_issuer_to_ro_buffer; // for branch only
  wire[`REG_TYPE] next_pc_from_issuer_to_ro_buffer; // for branch only

  wire[`RO_BUFFER_ID_TYPE] dest_from_issuer_to_ls_buffer;
  wire[`OP_TYPE] op_from_issuer_to_ls_buffer;
  wire[`RO_BUFFER_ID_TYPE] qj_from_issuer_to_ls_buffer;
  wire[`RO_BUFFER_ID_TYPE] qk_from_issuer_to_ls_buffer;
  wire[`REG_TYPE] vj_from_issuer_to_ls_buffer;
  wire[`REG_TYPE] vk_from_issuer_to_ls_buffer;
  wire[`IMM_TYPE] a_from_issuer_to_ls_buffer;

  // rss bus
  wire[`RO_BUFFER_ID_TYPE] dest_from_rs_station_to_rss_bus;
  wire[`REG_TYPE] value_from_rs_station_to_rss_bus;
  wire[`REG_TYPE] next_pc_from_rs_station_to_rss_bus;

  wire[`RO_BUFFER_ID_TYPE] dest_from_rss_bus_to_issuer;
  wire[`REG_TYPE] value_from_rss_bus_to_issuer;

  wire[`RO_BUFFER_ID_TYPE] dest_from_rss_bus_to_rs_station;
  wire[`REG_TYPE] value_from_rss_bus_to_rs_station;

  wire[`RO_BUFFER_ID_TYPE] dest_from_rss_bus_to_ls_buffer;
  wire[`REG_TYPE] value_from_rss_bus_to_ls_buffer;

  wire[`RO_BUFFER_ID_TYPE] dest_from_rss_bus_to_ro_buffer;
  wire[`REG_TYPE] value_from_rss_bus_to_ro_buffer;
  wire[`REG_TYPE] next_pc_from_rss_bus_to_ro_buffer;

  // lsb bus
  wire[`RO_BUFFER_ID_TYPE] dest_from_ls_buffer_to_lsb_bus;
  wire[`REG_TYPE] value_from_ls_buffer_to_lsb_bus;

  wire[`RO_BUFFER_ID_TYPE] dest_from_lsb_bus_to_issuer;
  wire[`REG_TYPE] value_from_lsb_bus_to_issuer;

  wire[`RO_BUFFER_ID_TYPE] dest_from_lsb_bus_to_rs_station;
  wire[`REG_TYPE] value_from_lsb_bus_to_rs_station;

  wire[`RO_BUFFER_ID_TYPE] dest_from_lsb_bus_to_ls_buffer;
  wire[`REG_TYPE] value_from_lsb_bus_to_ls_buffer;

  wire[`RO_BUFFER_ID_TYPE] dest_from_lsb_bus_to_ro_buffer;
  wire[`REG_TYPE] value_from_lsb_bus_to_ro_buffer;

  // rob bus
  wire reset_from_ro_buffer_to_rob_bus;
  wire[`BH_TABLE_ID_TYPE] pc_from_ro_buffer_to_rob_bus;
  wire[`REG_TYPE] next_pc_from_ro_buffer_to_rob_bus;
  wire[`RO_BUFFER_ID_TYPE] dest_from_ro_buffer_to_rob_bus;
  wire ls_select_from_ro_buffer_to_rob_bus;
  wire ls_select_from_rob_bus_to_ls_buffer;
  wire br_from_ro_buffer_to_rob_bus;
  wire is_taken_from_ro_buffer_to_rob_bus;

  wire reset_from_rob_bus_to_issuer;
  wire reset_from_rob_bus_to_rs_station;
  wire reset_from_rob_bus_to_ls_buffer;
  wire[`RO_BUFFER_ID_TYPE] dest_from_rob_bus_to_ls_buffer;
  wire reset_from_rob_bus_to_ro_buffer;
  wire reset_from_rob_bus_to_reg_file;

  rob_bus rob_bus_0(
            .reset_from_ro_buffer(reset_from_ro_buffer_to_rob_bus),
            .pc_from_ro_buffer(pc_from_ro_buffer_to_rob_bus),
            .next_pc_from_ro_buffer(next_pc_from_ro_buffer_to_rob_bus),
            .dest_from_ro_buffer(dest_from_ro_buffer_to_rob_bus),
            .ls_select_from_ro_buffer(ls_select_from_ro_buffer_to_rob_bus),
            .br_from_ro_buffer(br_from_ro_buffer_to_rob_bus),
            .is_taken_from_ro_buffer(is_taken_from_ro_buffer_to_rob_bus),

            .reset_to_inst_fetcher(reset_from_rob_bus_to_inst_fetcher),
            .next_pc_to_inst_fetcher(next_pc_from_rob_bus_to_inst_fetcher),

            .reset_to_ls_buffer(reset_from_rob_bus_to_ls_buffer),
            .dest_to_ls_buffer(dest_from_rob_bus_to_ls_buffer),
            .ls_select_to_ls_buffer(ls_select_from_rob_bus_to_ls_buffer),

            .valid_to_br_predictor(valid_from_rob_bus_to_br_predictor),
            .pc_to_br_predictor(pc_from_rob_bus_to_br_predictor),
            .is_taken_to_br_predictor(is_taken_from_rob_bus_to_br_predictor),

            .reset_to_issuer(reset_from_rob_bus_to_issuer),
            .reset_to_rs_station(reset_from_rob_bus_to_rs_station),
            .reset_to_ro_buffer(reset_from_rob_bus_to_ro_buffer),
            .reset_to_reg_file(reset_from_rob_bus_to_reg_file));

  lsb_bus lsb_bus_0(
            .dest_from_ls_buffer(dest_from_ls_buffer_to_lsb_bus),
            .value_from_ls_buffer(value_from_ls_buffer_to_lsb_bus),

            .dest_to_issuer(dest_from_lsb_bus_to_issuer),
            .value_to_issuer(value_from_lsb_bus_to_issuer),

            .dest_to_rs_station(dest_from_lsb_bus_to_rs_station),
            .value_to_rs_station(value_from_lsb_bus_to_rs_station),

            .dest_to_ls_buffer(dest_from_lsb_bus_to_ls_buffer),
            .value_to_ls_buffer(value_from_lsb_bus_to_ls_buffer),

            .dest_to_ro_buffer(dest_from_lsb_bus_to_ro_buffer),
            .value_to_ro_buffer(value_from_lsb_bus_to_ro_buffer)
          );

  rss_bus rss_bus_0(
            .dest_from_rs_station(dest_from_rs_station_to_rss_bus),
            .value_from_rs_station(value_from_rs_station_to_rss_bus),
            .next_pc_from_rs_station(next_pc_from_rs_station_to_rss_bus),

            .dest_to_issuer(dest_from_rss_bus_to_issuer),
            .value_to_issuer(value_from_rss_bus_to_issuer),

            .dest_to_rs_station(dest_from_rss_bus_to_rs_station),
            .value_to_rs_station(value_from_rss_bus_to_rs_station),

            .dest_to_ls_buffer(dest_from_rss_bus_to_ls_buffer),
            .value_to_ls_buffer(value_from_rss_bus_to_ls_buffer),

            .dest_to_ro_buffer(dest_from_rss_bus_to_ro_buffer),
            .value_to_ro_buffer(value_from_rss_bus_to_ro_buffer),
            .next_pc_to_ro_buffer(next_pc_from_rss_bus_to_ro_buffer)
          );

  wire[`RO_BUFFER_ID_TYPE] dest_from_ro_buffer_to_reg_file;
  wire[`REG_ID_TYPE] rd_from_ro_buffer_to_reg_file;
  wire[`REG_TYPE] value_from_ro_buffer_to_reg_file;

  reg_file reg_file_0(
             .clk(clk_in),
             .rst(rst),
             .rdy(rdy_in),

             .rs_from_issuer(rs_from_issuer_to_reg_file),
             .vj_to_issuer(vj_from_reg_file_to_issuer),
             .qj_to_issuer(qj_from_reg_file_to_issuer),
             .rt_from_issuer(rt_from_issuer_to_reg_file),
             .vk_to_issuer(vk_from_reg_file_to_issuer),
             .qk_to_issuer(qk_from_reg_file_to_issuer),

             .rd_from_issuer(rd_from_issuer_to_reg_file),
             .dest_from_issuer(dest_from_issuer_to_reg_file),

             .dest_from_ro_buffer(dest_from_ro_buffer_to_reg_file),
             .rd_from_ro_buffer(rd_from_ro_buffer_to_reg_file),
             .value_from_ro_buffer(value_from_ro_buffer_to_reg_file),

             .reset_from_rob_bus(reset_from_rob_bus_to_reg_file));

  issuer issuer_0(
           .clk(clk_in),
           .rst(rst),
           .rdy(rdy_in),

           .is_any_full(is_any_full),

           .ready_from_inst_fetcher(ready_from_inst_fetcher_to_issuer),
           .pc_from_inst_fetcher(pc_from_inst_fetcher_to_issuer),
           .next_pc_from_inst_fetcher(next_pc_from_inst_fetcher_to_issuer),
           .inst_from_inst_fetcher(inst_from_inst_fetcher_to_issuer),

           // reg file
           .rs_to_reg_file(rs_from_issuer_to_reg_file),
           .vj_from_reg_file(vj_from_reg_file_to_issuer),
           .qj_from_reg_file(qj_from_reg_file_to_issuer),

           .rt_to_reg_file(rt_from_issuer_to_reg_file),
           .vk_from_reg_file(vk_from_reg_file_to_issuer),
           .qk_from_reg_file(qk_from_reg_file_to_issuer),

           .rd_to_reg_file(rd_from_issuer_to_reg_file),
           .dest_to_reg_file(dest_from_issuer_to_reg_file),

           // ro buffer
           .qj_to_ro_buffer(qj_from_issuer_to_ro_buffer),
           .qk_to_ro_buffer(qk_from_issuer_to_ro_buffer),
           .valid_of_vj_from_ro_buffer(valid_of_vj_from_ro_buffer_to_issuer),
           .vj_from_ro_buffer(vj_from_ro_buffer_to_issuer),
           .valid_of_vk_from_ro_buffer(valid_of_vk_from_ro_buffer_to_issuer),
           .vk_from_ro_buffer(vk_from_ro_buffer_to_issuer),

           .dest_from_ro_buffer(dest_from_ro_buffer_to_issuer),
           .valid_to_ro_buffer(valid_from_issuer_to_ro_buffer),
           .signal_to_ro_buffer(signal_from_issuer_to_ro_buffer),
           .rd_to_ro_buffer(rd_from_issuer_to_ro_buffer),
           .pc_to_ro_buffer(pc_from_issuer_to_ro_buffer),
           .next_pc_to_ro_buffer(next_pc_from_issuer_to_ro_buffer),

           // rs station
           .dest_to_rs_station(dest_from_issuer_to_rs_station),
           .op_to_rs_station(op_from_issuer_to_rs_station),
           .qj_to_rs_station(qj_from_issuer_to_rs_station),
           .qk_to_rs_station(qk_from_issuer_to_rs_station),
           .vj_to_rs_station(vj_from_issuer_to_rs_station),
           .vk_to_rs_station(vk_from_issuer_to_rs_station),
           .imm_to_rs_station(imm_from_issuer_to_rs_station),
           .pc_to_rs_station(pc_from_issuer_to_rs_station),

           .dest_to_ls_buffer(dest_from_issuer_to_ls_buffer),
           .op_to_ls_buffer(op_from_issuer_to_ls_buffer),
           .qj_to_ls_buffer(qj_from_issuer_to_ls_buffer),
           .qk_to_ls_buffer(qk_from_issuer_to_ls_buffer),
           .vj_to_ls_buffer(vj_from_issuer_to_ls_buffer),
           .vk_to_ls_buffer(vk_from_issuer_to_ls_buffer),
           .a_to_ls_buffer(a_from_issuer_to_ls_buffer),

           .reset_from_rob_bus(reset_from_rob_bus_to_issuer)
         );

  rs_station rs_station_0(
               .clk(clk_in),
               .rst(rst),
               .rdy(rdy_in),

               // for issuer
               .dest_from_issuer(dest_from_issuer_to_rs_station),
               .op_from_issuer(op_from_issuer_to_rs_station),
               .qj_from_issuer(qj_from_issuer_to_rs_station),
               .qk_from_issuer(qk_from_issuer_to_rs_station),
               .vj_from_issuer(vj_from_issuer_to_rs_station),
               .vk_from_issuer(vk_from_issuer_to_rs_station),
               .imm_from_issuer(imm_from_issuer_to_rs_station),
               .pc_from_issuer(pc_from_issuer_to_rs_station),

               .dest_from_lsb_bus(dest_from_lsb_bus_to_rs_station),
               .value_from_lsb_bus(value_from_lsb_bus_to_rs_station),

               .dest_from_rss_bus(dest_from_rss_bus_to_rs_station),
               .value_from_rss_bus(value_from_rss_bus_to_rs_station),

               .dest_to_rss_bus(dest_from_rs_station_to_rss_bus),
               .value_to_rss_bus(value_from_rs_station_to_rss_bus),
               .next_pc_to_rss_bus(next_pc_from_rs_station_to_rss_bus),

               .reset_from_rob_bus(reset_from_rob_bus_to_rs_station),

               .is_rs_station_full(is_rs_station_full));

  new_ls_buffer ls_buffer_0(
                  .clk(clk_in),
                  .rst(rst),
                  .rdy(rdy_in),

                  .dest_from_issuer(dest_from_issuer_to_ls_buffer),
                  .op_from_issuer(op_from_issuer_to_ls_buffer),
                  .qj_from_issuer(qj_from_issuer_to_ls_buffer),
                  .qk_from_issuer(qk_from_issuer_to_ls_buffer),
                  .vj_from_issuer(vj_from_issuer_to_ls_buffer),
                  .vk_from_issuer(vk_from_issuer_to_ls_buffer),
                  .a_from_issuer(a_from_issuer_to_ls_buffer),

                  .dest_from_lsb_bus(dest_from_lsb_bus_to_ls_buffer),
                  .value_from_lsb_bus(value_from_lsb_bus_to_ls_buffer),

                  .dest_from_rss_bus(dest_from_rss_bus_to_ls_buffer),
                  .value_from_rss_bus(value_from_rss_bus_to_ls_buffer),

                  .reset_from_rob_bus(reset_from_rob_bus_to_ls_buffer),
                  .dest_from_rob_bus(dest_from_rob_bus_to_ls_buffer),
                  .ls_select_from_rob_bus(ls_select_from_rob_bus_to_ls_buffer),

                  .valid_to_mem_ctrler(valid_from_dcache_to_mem_ctrler),
                  .rw_flag_to_mem_ctrler(rw_flag_from_dcache_to_mem_ctrler),
                  .addr_to_mem_ctrler(addr_from_dcache_to_mem_ctrler),
                  .cache_line_to_mem_ctrler(data_from_dcache_to_mem_ctrler),
                  .ready_from_mem_ctrler(ready_from_mem_ctrler_to_dcache),
                  .cache_line_from_mem_ctrler(data_from_mem_ctrler_to_dcache),

                  .dest_to_lsb_bus(dest_from_ls_buffer_to_lsb_bus),
                  .value_to_lsb_bus(value_from_ls_buffer_to_lsb_bus),

                  .valid_from_io_to_mem_ctrler(valid_from_io_to_mem_ctrler),
                  .rw_flag_from_io_to_mem_ctrler(rw_flag_from_io_to_mem_ctrler),
                  .addr_from_io_to_mem_ctrler(addr_from_io_to_mem_ctrler),
                  .byte_from_io_to_mem_ctrler(data_from_io_to_mem_ctrler),
                  .ready_from_mem_ctrler_to_io(ready_from_mem_ctrler_to_io),
                  .byte_from_mem_ctrler_to_io(data_from_mem_ctrler_to_io),

                  .is_ls_buffer_full(is_ls_buffer_full));

  ro_buffer ro_buffer_0(
              .clk(clk_in),
              .rst(rst),
              .rdy(rdy_in),

              .is_ro_buffer_full(is_ro_buffer_full),

              .valid_from_issuer(valid_from_issuer_to_ro_buffer),
              .signal_from_issuer(signal_from_issuer_to_ro_buffer),
              .rd_from_issuer(rd_from_issuer_to_ro_buffer),
              .pc_from_issuer(pc_from_issuer_to_ro_buffer),
              .next_pc_from_issuer(next_pc_from_issuer_to_ro_buffer),
              .dest_to_issuer(dest_from_ro_buffer_to_issuer),

              .qj_from_issuer(qj_from_issuer_to_ro_buffer),
              .valid_of_vj_to_issuer(valid_of_vj_from_ro_buffer_to_issuer),
              .vj_to_issuer(vj_from_ro_buffer_to_issuer),

              .qk_from_issuer(qk_from_issuer_to_ro_buffer),
              .valid_of_vk_to_issuer(valid_of_vk_from_ro_buffer_to_issuer),
              .vk_to_issuer(vk_from_ro_buffer_to_issuer),

              .reset_to_rob_bus(reset_from_ro_buffer_to_rob_bus),
              .pc_to_rob_bus(pc_from_ro_buffer_to_rob_bus),
              .next_pc_to_rob_bus(next_pc_from_ro_buffer_to_rob_bus),
              .dest_to_rob_bus(dest_from_ro_buffer_to_rob_bus),
              .ls_select_to_rob_bus(ls_select_from_ro_buffer_to_rob_bus),
              .br_to_rob_bus(br_from_ro_buffer_to_rob_bus),
              .is_taken_to_rob_bus(is_taken_from_ro_buffer_to_rob_bus),

              .reset_from_rob_bus(reset_from_rob_bus_to_ro_buffer),

              .dest_from_lsb_bus(dest_from_lsb_bus_to_ro_buffer),
              .value_from_lsb_bus(value_from_lsb_bus_to_ro_buffer),

              .dest_from_rss_bus(dest_from_rss_bus_to_ro_buffer),
              .value_from_rss_bus(value_from_rss_bus_to_ro_buffer),
              .next_pc_from_rss_bus(next_pc_from_rss_bus_to_ro_buffer),

              .dest_to_reg_file(dest_from_ro_buffer_to_reg_file),
              .rd_to_reg_file(rd_from_ro_buffer_to_reg_file),
              .value_to_reg_file(value_from_ro_buffer_to_reg_file));

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
    if (rst) begin

    end else if (!rdy_in) begin

    end else begin

    end
  end

endmodule
