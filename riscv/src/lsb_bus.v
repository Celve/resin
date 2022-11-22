`ifndef LSB_BUS_V
`define LSB_BUS_V

`include "config.v"

module lsb_bus(
    input wire[`RO_BUFFER_ID_TYPE] dest_from_ls_buffer,
    input wire[`REG_TYPE] value_from_ls_buffer,

    output wire[`RO_BUFFER_ID_TYPE] dest_to_issuer,
    output wire[`REG_TYPE] value_to_issuer,

    output wire[`RO_BUFFER_ID_TYPE] dest_to_rs_station,
    output wire[`REG_TYPE] value_to_rs_station,

    output wire[`RO_BUFFER_ID_TYPE] dest_to_ls_buffer,
    output wire[`REG_TYPE] value_to_ls_buffer,

    output wire[`RO_BUFFER_ID_TYPE] dest_to_ro_buffer,
    output wire[`REG_TYPE] value_to_ro_buffer
  );

  assign dest_to_issuer = dest_from_ls_buffer;
  assign value_to_issuer = value_from_ls_buffer;

  assign dest_to_rs_station = dest_from_ls_buffer;
  assign value_to_rs_station = value_from_ls_buffer;

  assign dest_to_ls_buffer = dest_from_ls_buffer;
  assign value_to_ls_buffer = value_from_ls_buffer;

  assign dest_to_ro_buffer = dest_from_ls_buffer;
  assign value_to_ro_buffer = value_from_ls_buffer;

endmodule

`endif
