`ifndef ROB_BUS_V
`define ROB_BUS_V

`include "config.v"

module rob_bus(
    input wire reset_from_ro_buffer,
    input wire[`REG_TYPE] pc_from_ro_buffer,
    input wire store_from_ro_buffer,

    output wire reset_to_inst_fetcher,
    output wire[`REG_TYPE] pc_to_inst_fetcher,

    output wire reset_to_ls_buffer,
    output wire store_to_ls_buffer,

    output wire reset_to_issuer,
    output wire reset_to_rs_station,
    output wire reset_to_ro_buffer,
    output wire reset_to_reg_file
  );

  assign reset_to_inst_fetcher = reset_from_ro_buffer;
  assign pc_to_inst_fetcher = pc_from_ro_buffer;

  assign reset_to_issuer = reset_from_ro_buffer;
  assign reset_to_rs_station = reset_from_ro_buffer;
  assign reset_to_ls_buffer = reset_from_ro_buffer;
  assign reset_to_ro_buffer = reset_from_ro_buffer;
  assign reset_to_reg_file = reset_from_ro_buffer;

endmodule

`endif
