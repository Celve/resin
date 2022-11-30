`ifndef ROB_BUS_V
`define ROB_BUS_V

`include "config.v"

module rob_bus(
    input wire reset_from_ro_buffer,
    input wire[`BH_TABLE_ID_TYPE] pc_from_ro_buffer,
    input wire[`REG_TYPE] next_pc_from_ro_buffer,
    input wire[`RO_BUFFER_ID_TYPE] dest_from_ro_buffer,
    input wire ls_select_from_ro_buffer,
    input wire br_from_ro_buffer,
    input wire is_taken_from_ro_buffer,

    output wire reset_to_inst_fetcher,
    output wire[`REG_TYPE] next_pc_to_inst_fetcher,

    output wire reset_to_ls_buffer,
    output wire[`RO_BUFFER_ID_TYPE] dest_to_ls_buffer,
    output wire ls_select_to_ls_buffer,

    output wire valid_to_br_predictor,
    output wire[`BH_TABLE_ID_TYPE] pc_to_br_predictor,
    output is_taken_to_br_predictor,

    output wire reset_to_issuer,
    output wire reset_to_rs_station,
    output wire reset_to_ro_buffer,
    output wire reset_to_reg_file
  );

  assign reset_to_inst_fetcher = reset_from_ro_buffer;
  assign next_pc_to_inst_fetcher = next_pc_from_ro_buffer;

  assign reset_to_ls_buffer = reset_from_ro_buffer;
  assign dest_to_ls_buffer = dest_from_ro_buffer;
  assign ls_select_to_ls_buffer = ls_select_from_ro_buffer;

  assign valid_to_br_predictor = br_from_ro_buffer;
  assign pc_to_br_predictor = pc_from_ro_buffer[`BH_TABLE_ID_TYPE];
  assign is_taken_to_br_predictor = is_taken_from_ro_buffer;

  assign reset_to_issuer = reset_from_ro_buffer;
  assign reset_to_rs_station = reset_from_ro_buffer;
  assign reset_to_ro_buffer = reset_from_ro_buffer;
  assign reset_to_reg_file = reset_from_ro_buffer;

endmodule

`endif
