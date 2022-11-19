`ifndef LS_BUFFER_V
`define LS_BUFFER_V

`include "config.v"

module ls_buffer(
    input wire clk,
    input wire rst,
    input wire rdy,

    // for issuer
    input wire[`RO_BUFFER_ID_TYPE] dest_from_issuer,
    input wire[`OP_TYPE] op_from_issuer,
    input wire[`RO_BUFFER_ID_TYPE] qj_from_issuer,
    input wire[`RO_BUFFER_ID_TYPE] qk_from_issuer,
    input wire[`REG_TYPE] vj_from_issuer,
    input wire[`REG_TYPE] vk_from_issuer,

    // for ls buffer
    input wire[`RO_BUFFER_ID_TYPE] dest_from_lsb_bus,
    input wire[`REG_TYPE] value_from_lsb_bus,

    // for res station
    input wire[`RO_BUFFER_ID_TYPE] dest_from_rss_bus,
    input wire[`REG_TYPE] value_from_rss_bus,

    // for lsb bus
    output reg[`RO_BUFFER_ID_TYPE] dest_to_lsb_bus, // TODO: still need to design more dedicate
    output reg[`REG_TYPE] value_to_lsb_bus,
    output reg[`REG_TYPE] pc_to_lsb_bus,

    // for inst_fetcher and others
    output wire is_ls_buffer_full);

  reg[`CACHE_TAG_TYPE] cache_tags[`INST_CACHE_SIZE - 1:0];
  reg[`CACHE_LINE_TYPE][`BYTE_TYPE] cache_lines[`INST_CACHE_SIZE - 1:0];
  reg cache_valid_bits[`INST_CACHE_SIZE - 1:0];

  reg[`OP_TYPE] op[`LOAD_STORE_BUFFER_TYPE];
  reg[`RO_BUFFER_ID_TYPE] qj[`LOAD_STORE_BUFFER_TYPE];
  reg[`RO_BUFFER_ID_TYPE] qk[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] vj[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] vk[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] a[`LOAD_STORE_BUFFER_TYPE];
  reg busy[`LOAD_STORE_BUFFER_TYPE];

  assign is_ls_buffer_full =
         busy[1] & busy[2] & busy[3] & busy[4] &
         busy[5] & busy[6] & busy[7] & busy[8] &
         busy[9] & busy[10] & busy[11] & busy[12] &
         busy[13] & busy[14] & busy[15] & busy[16];

  wire[`LS_BUFFER_ID_TYPE] free_index =
      !busy[1] ? 1 :
      !busy[2] ? 2 :
      !busy[3] ? 3 :
      !busy[4] ? 4 :
      !busy[5] ? 5 :
      !busy[6] ? 6 :
      !busy[7] ? 7 :
      !busy[8] ? 8 :
      !busy[9] ? 9 :
      !busy[10] ? 10 :
      !busy[11] ? 11 :
      !busy[12] ? 12 :
      !busy[13] ? 13 :
      !busy[14] ? 14 :
      !busy[15] ? 15 :
      !busy[16] ? 16 :
      0;

  wire[`LS_BUFFER_ID_TYPE] calc_index =
      !qj[1] && a[1] && busy[1] ? 1 :
      !qj[2] && a[2] && busy[2] ? 2 :
      !qj[3] && a[3] && busy[3] ? 3 :
      !qj[4] && a[4] && busy[4] ? 4 :
      !qj[5] && a[5] && busy[5] ? 5 :
      !qj[6] && a[6] && busy[6] ? 6 :
      !qj[7] && a[7] && busy[7] ? 7 :
      !qj[8] && a[8] && busy[8] ? 8 :
      !qj[9] && a[9] && busy[9] ? 9 :
      !qj[10] && a[10] && busy[10] ? 10 :
      !qj[11] && a[11] && busy[11] ? 11 :
      !qj[12] && a[12] && busy[12] ? 12 :
      !qj[13] && a[13] && busy[13] ? 13 :
      !qj[14] && a[14] && busy[14] ? 14 :
      !qj[15] && a[15] && busy[15] ? 15 :
      !qj[16] && a[16] && busy[16] ? 16 :
      0;

  wire[`RES_STATION_ID_TYPE] exec_index =
      !qj[1] && !qk[1] && !a[1] && busy[1] ? 1 :
      !qj[2] && !qk[2] && !a[2] && busy[2] ? 2 :
      !qj[3] && !qk[3] && !a[3] && busy[3] ? 3 :
      !qj[4] && !qk[4] && !a[4] && busy[4] ? 4 :
      !qj[5] && !qk[5] && !a[5] && busy[5] ? 5 :
      !qj[6] && !qk[6] && !a[6] && busy[6] ? 6 :
      !qj[7] && !qk[7] && !a[7] && busy[7] ? 7 :
      !qj[8] && !qk[8] && !a[8] && busy[8] ? 8 :
      !qj[9] && !qk[9] && !a[9] && busy[9] ? 9 :
      !qj[10] && !qk[10] && !a[10] && busy[10] ? 10 :
      !qj[11] && !qk[11] && !a[11] && busy[11] ? 11 :
      !qj[12] && !qk[12] && !a[12] && busy[12] ? 12 :
      !qj[13] && !qk[13] && !a[13] && busy[13] ? 13 :
      !qj[14] && !qk[14] && !a[14] && busy[14] ? 14 :
      !qj[15] && !qk[15] && !a[15] && busy[15] ? 15 :
      !qj[16] && !qk[16] && !a[16] && busy[16] ? 16 :
      0;

  always @(posedge clk) begin
    if (rst) begin
      for (integer i = 0; i < `LOAD_STORE_BUFFER_SIZE; i = i + 1) begin
        op[i] <= 0;
        qj[i] <= 0;
        qk[i] <= 0;
        vj[i] <= 0;
        vk[i] <= 0;
        busy[i] <= 0;
      end
    end else begin
      if (dest_from_issuer) begin
        op[free_index] <= op_from_issuer;
        qj[free_index] <= qj_from_issuer;
        qk[free_index] <= qk_from_issuer;
        vj[free_index] <= vj_from_issuer;
        vk[free_index] <= vk_from_issuer;
        busy[free_index] <= 1;
      end
    end
  end


  always @(posedge clk) begin
    if (!rst) begin
      if (calc_index) begin
        vj[calc_index] <= vj[calc_index] + a[calc_index];
        a[calc_index] <= 0;
      end
    end
  end

endmodule

`endif
