`ifndef RSS_BUS_V
`define RSS_BUS_V

`include "config.v"

module rss_bus(
    input wire[`RO_BUFFER_ID_TYPE] dest_from_rs_station,
    input wire[`REG_TYPE] value_from_rs_station,
    input wire[`REG_TYPE] pc_from_rs_station,

    output wire[`RO_BUFFER_ID_TYPE] dest_to_issuer,
    output wire[`REG_TYPE] value_to_issuer,

    output wire[`RO_BUFFER_ID_TYPE] dest_to_rs_station,
    output wire[`REG_TYPE] value_to_rs_station,

    output wire[`RO_BUFFER_ID_TYPE] dest_to_ls_buffer,
    output wire[`REG_TYPE] value_to_ls_buffer,

    output wire[`RO_BUFFER_ID_TYPE] dest_to_ro_buffer,
    output wire[`REG_TYPE] value_to_ro_buffer,
    output wire[`REG_TYPE] pc_to_ro_buffer
  );

  assign dest_to_rs_station = dest_from_rs_station;
  assign value_to_rs_station = value_from_rs_station;

  assign dest_to_ls_buffer = dest_from_rs_station;
  assign value_to_ls_buffer = value_from_rs_station;

  assign dest_to_ro_buffer = dest_from_rs_station;
  assign value_to_ro_buffer = value_from_rs_station;
  assign pc_to_ro_buffer = pc_from_rs_station;

endmodule

`endif
