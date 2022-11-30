`ifndef RES_STATION_V
`define RES_STATION_V

`include "config.v"
`include "al_unit.v"

module rs_station(
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
    input wire[`IMM_TYPE] imm_from_issuer,
    input wire[`REG_TYPE] pc_from_issuer,

    // for ls buffer
    input wire[`RO_BUFFER_ID_TYPE] dest_from_lsb_bus,
    input wire[`REG_TYPE] value_from_lsb_bus,

    // for res station
    input wire[`RO_BUFFER_ID_TYPE] dest_from_rss_bus,
    input wire[`REG_TYPE] value_from_rss_bus,

    // for rss bus, which would be distributed towards res statio, reorder buffer, and issuer
    output reg[`RO_BUFFER_ID_TYPE] dest_to_rss_bus, // TODO: still need to design more dedicate
    output reg[`REG_TYPE] value_to_rss_bus,
    output reg[`REG_TYPE] next_pc_to_rss_bus,

    // for rob bus
    input reset_from_rob_bus,

    // for inst_fetcher and others
    output wire is_rs_station_full);

  parameter[2:0] IDLE = 0;
  parameter[2:0] WAITING = 1;

  reg[`OP_TYPE] op[`RESERVATION_STATION_TYPE];
  reg[`RO_BUFFER_ID_TYPE] qj[`RESERVATION_STATION_TYPE];
  reg[`RO_BUFFER_ID_TYPE] qk[`RESERVATION_STATION_TYPE];
  reg[`REG_TYPE] vj[`RESERVATION_STATION_TYPE];
  reg[`REG_TYPE] vk[`RESERVATION_STATION_TYPE];
  reg[`REG_TYPE] a[`RESERVATION_STATION_TYPE]; // in this case, it's used to store pc
  reg[`REG_TYPE] imm[`RESERVATION_STATION_TYPE]; // temporary supplement
  reg busy[`RESERVATION_STATION_TYPE];
  reg[`RO_BUFFER_ID_TYPE] dest[`RESERVATION_STATION_TYPE];
  reg state; // only 0 or 1
  reg[`RES_STATION_ID_TYPE] size;

  // for alu
  reg[`OP_TYPE] op_to_al_unit;
  reg[`REG_TYPE] rs_to_al_unit;
  reg[`REG_TYPE] rt_to_al_unit;
  reg[`REG_TYPE] pc_to_al_unit;
  reg[`REG_TYPE] imm_to_al_unit;
  wire valid_from_al_unit;
  wire[`REG_TYPE] value_from_al_unit;
  wire[`REG_TYPE] next_pc_from_al_unit;
  reg[`RES_STATION_ID_TYPE] last_exec_index;

  wire is_any_reset = rst || reset_from_rob_bus;

  al_unit al_unit_0(
            .op(op_to_al_unit),
            .rs(rs_to_al_unit),
            .rt(rt_to_al_unit),
            .pc(pc_to_al_unit),
            .imm(imm_to_al_unit),
            .valid(valid_from_al_unit),
            .value(value_from_al_unit),
            .next_pc(next_pc_from_al_unit));

  assign is_rs_station_full = size >= `RESERVATION_STATION_SIZE_MINUS_1; // FIXME: currently use strategy of pre-full

  wire[`RES_STATION_ID_TYPE] free_index =
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

  wire[`RES_STATION_ID_TYPE] exec_index =
      !qj[1] && !qk[1] && busy[1] ? 1 :
      !qj[2] && !qk[2] && busy[2] ? 2 :
      !qj[3] && !qk[3] && busy[3] ? 3 :
      !qj[4] && !qk[4] && busy[4] ? 4 :
      !qj[5] && !qk[5] && busy[5] ? 5 :
      !qj[6] && !qk[6] && busy[6] ? 6 :
      !qj[7] && !qk[7] && busy[7] ? 7 :
      !qj[8] && !qk[8] && busy[8] ? 8 :
      !qj[9] && !qk[9] && busy[9] ? 9 :
      !qj[10] && !qk[10] && busy[10] ? 10 :
      !qj[11] && !qk[11] && busy[11] ? 11 :
      !qj[12] && !qk[12] && busy[12] ? 12 :
      !qj[13] && !qk[13] && busy[13] ? 13 :
      !qj[14] && !qk[14] && busy[14] ? 14 :
      !qj[15] && !qk[15] && busy[15] ? 15 :
      !qj[16] && !qk[16] && busy[16] ? 16 :
      0;

  integer i;

  always @(posedge clk) begin
    if (is_any_reset) begin
      size <= 0;
      state <= 0;

      for (i = 1; i < `RESERVATION_STATION_SIZE_PLUS_1; i = i + 1) begin
        op[i] <= 0;
        qj[i] <= 0;
        qk[i] <= 0;
        vj[i] <= 0;
        vk[i] <= 0;
        a[i] <= 0;
        imm[i] <= 0;
        dest[i] <= 0;
        busy[i] <= 0;
      end

      last_exec_index <= 0;

      dest_to_rss_bus <= 0;
      value_to_rss_bus <= 0;
      next_pc_to_rss_bus <= 0;
    end else if (rdy) begin
      if (dest_from_lsb_bus) begin
        for (i = 1; i < `RESERVATION_STATION_SIZE_PLUS_1; i = i + 1) begin
          if (busy[i] && qj[i] == dest_from_lsb_bus) begin
            qj[i] <= 0;
            vj[i] <= value_from_lsb_bus;
          end
          if (busy[i] && qk[i] == dest_from_lsb_bus) begin
            qk[i] <= 0;
            vk[i] <= value_from_lsb_bus;
          end
        end
      end
      if (dest_from_rss_bus) begin
        for (i = 1; i < `RESERVATION_STATION_SIZE_PLUS_1; i = i + 1) begin
          if (qj[i] == dest_from_rss_bus) begin
            qj[i] <= 0;
            vj[i] <= value_from_rss_bus;
          end
          if (qk[i] == dest_from_rss_bus) begin
            qk[i] <= 0;
            vk[i] <= value_from_rss_bus;
          end
        end
      end
      if (state == IDLE && exec_index) begin
        state <= WAITING;
        op_to_al_unit <= op[exec_index];
        rs_to_al_unit <= vj[exec_index];
        rt_to_al_unit <= vk[exec_index];
        pc_to_al_unit <= a[exec_index];
        imm_to_al_unit <= imm[exec_index];
        last_exec_index <= exec_index;

        dest_to_rss_bus <= 0;
        value_to_rss_bus <= 0;
        next_pc_to_rss_bus <= 0;
      end else if (state == WAITING && valid_from_al_unit) begin
        dest[last_exec_index] <= 0;
        busy[last_exec_index] <= 0;
        state <= IDLE;

        // write result to ro buffer and res station and issuer
        dest_to_rss_bus <= dest[last_exec_index];
        value_to_rss_bus <= value_from_al_unit;
        next_pc_to_rss_bus <= next_pc_from_al_unit;
      end else begin
        dest_to_rss_bus <= 0;
        value_to_rss_bus <= 0;
        next_pc_to_rss_bus <= 0;
      end

      // add new entry to a empty slot
      if (dest_from_issuer) begin
        op[free_index] <= op_from_issuer;

        // never forget to check this!!!
        if (dest_from_rss_bus && qj_from_issuer == dest_from_rss_bus) begin
          qj[free_index] <= 0;
          vj[free_index] <= value_from_rss_bus;
        end else if (dest_from_lsb_bus && qj_from_issuer == dest_from_lsb_bus) begin
          qj[free_index] <= 0;
          vj[free_index] <= value_from_lsb_bus;
        end else begin
          qj[free_index] <= qj_from_issuer;
          vj[free_index] <= vj_from_issuer;
        end

        if (dest_from_rss_bus && qk_from_issuer == dest_from_rss_bus) begin
          qk[free_index] <= 0;
          vk[free_index] <= value_from_rss_bus;
        end else if (dest_from_lsb_bus && qk_from_issuer == dest_from_lsb_bus) begin
          qk[free_index] <= 0;
          vk[free_index] <= value_from_lsb_bus;
        end else begin
          qk[free_index] <= qk_from_issuer;
          vk[free_index] <= vk_from_issuer;
        end

        imm[free_index] <= imm_from_issuer;
        a[free_index] <= pc_from_issuer;
        dest[free_index] <= dest_from_issuer;
        busy[free_index] <= 1;
      end
      size <= size + (dest_from_issuer != 0) - (state == WAITING && valid_from_al_unit);
    end
  end

endmodule

`endif
