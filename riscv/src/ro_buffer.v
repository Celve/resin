`ifndef RO_BUFFER_V
`define RO_BUFFER_V

`include "config.v"

module ro_buffer(
    input wire clk,
    input wire rst,
    input wire rdy,

    // for all
    output wire is_ro_buffer_full,

    // for issuer
    input wire valid_from_issuer,
    input wire[`ISSUER_TO_ROB_SIGNAL_TYPE] signal_from_issuer,
    input wire[`REG_ID_TYPE] rd_from_issuer, // for normal instruction only
    input wire[`REG_TYPE] pc_from_issuer,
    input wire[`REG_TYPE] next_pc_from_issuer, // for branch only
    output wire[`RO_BUFFER_ID_TYPE] dest_to_issuer,

    // for issuer
    input wire[`RO_BUFFER_ID_TYPE] qj_from_issuer, // FIXME: useless
    output wire valid_of_vj_to_issuer,
    output wire[`REG_TYPE] vj_to_issuer,

    input wire[`RO_BUFFER_ID_TYPE] qk_from_issuer, // FIXME: useless
    output wire valid_of_vk_to_issuer,
    output wire[`REG_TYPE] vk_to_issuer,

    // for rob bus
    output reg reset_to_rob_bus,
    output reg[`BH_TABLE_ID_TYPE] pc_to_rob_bus,
    output reg[`REG_TYPE] next_pc_to_rob_bus,
    output reg[`RO_BUFFER_ID_TYPE] dest_to_rob_bus,
    output reg ls_select_to_rob_bus,
    output reg br_to_rob_bus,
    output reg is_taken_to_rob_bus,

    input wire reset_from_rob_bus,

    // for lsb bus
    input wire[`RO_BUFFER_ID_TYPE] dest_from_lsb_bus,
    input wire[`REG_TYPE] value_from_lsb_bus,

    // for rss bus
    input wire[`RO_BUFFER_ID_TYPE] dest_from_rss_bus,
    input wire[`REG_TYPE] value_from_rss_bus,
    input wire[`REG_TYPE] next_pc_from_rss_bus,

    // for reg file
    output reg[`RO_BUFFER_ID_TYPE] dest_to_reg_file,
    output reg[`REG_ID_TYPE] rd_to_reg_file,
    output reg[`REG_TYPE] value_to_reg_file
  );

  reg[`RO_BUFFER_ID_TYPE] head; // head is the real head
  reg[`RO_BUFFER_ID_TYPE] tail; // tail - 1 is the real tail
  reg[`RO_BUFFER_ID_TYPE] size;

  reg status[`RO_BUFFER_TYPE];
  reg[`ISSUER_TO_ROB_SIGNAL_TYPE] signal[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] value[`RO_BUFFER_TYPE];
  reg[`REG_ID_TYPE] rd[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] pc[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] supposed_next_pc[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] correct_next_pc[`RO_BUFFER_TYPE];

  wire is_any_reset = rst || reset_from_rob_bus;

  assign is_ro_buffer_full = size >= `RO_BUFFER_SIZE_MINUS_1; // FIXME: currently use strategy of pre-full
  wire[`RO_BUFFER_ID_TYPE] next_tail = tail == `RO_BUFFER_SIZE ? 1 : tail + 1;
  assign dest_to_issuer = valid_from_issuer ? next_tail : tail;

  integer i;

  wire[`REG_TYPE] pc_head = pc[head];

  assign valid_of_vj_to_issuer =
         !qj_from_issuer ? 0 :
         status[qj_from_issuer] ? 1 :
         dest_from_lsb_bus && qj_from_issuer == dest_from_lsb_bus ? 1 :
         dest_from_rss_bus && qj_from_issuer == dest_from_rss_bus ? 1 :
         0;

  assign vj_to_issuer =
         !qj_from_issuer ? 0 :
         status[qj_from_issuer] ? value[qj_from_issuer] :
         dest_from_lsb_bus && qj_from_issuer == dest_from_lsb_bus ? value_from_lsb_bus :
         dest_from_rss_bus && qj_from_issuer == dest_from_rss_bus ? value_from_rss_bus :
         0;

  assign valid_of_vk_to_issuer =
         !qk_from_issuer ? 0 :
         status[qk_from_issuer] ? 1 :
         dest_from_lsb_bus && qk_from_issuer == dest_from_lsb_bus ? 1 :
         dest_from_rss_bus && qk_from_issuer == dest_from_rss_bus ? 1 :
         0;

  assign vk_to_issuer =
         !qk_from_issuer ? 0 :
         status[qk_from_issuer] ? value[qk_from_issuer] :
         dest_from_lsb_bus && qk_from_issuer == dest_from_lsb_bus ? value_from_lsb_bus :
         dest_from_rss_bus && qk_from_issuer == dest_from_rss_bus ? value_from_rss_bus :
         0;

  always @(posedge clk) begin
    if (is_any_reset) begin
      head <= 1;
      tail <= 1;
      size <= 0;

      reset_to_rob_bus <= 0;
      pc_to_rob_bus <= 0;
      next_pc_to_rob_bus <= 0;
      dest_to_rob_bus <= 0;
      ls_select_to_rob_bus <= 0;
      br_to_rob_bus <= 0;
      is_taken_to_rob_bus <= 0;

      dest_to_reg_file <= 0;
      rd_to_reg_file <= 0;
      value_to_reg_file <= 0;

      for (i = 1; i < `RO_BUFFER_SIZE_PLUS_1; i = i + 1) begin
        signal[i] <= 0;
        status[i] <= 0;
        value[i] <= 0;
        rd[i] <= 0;
        pc[i] <= 0;
        supposed_next_pc[i] <= 0;
        correct_next_pc[i] <= 0;
      end
    end else if (rdy) begin
      if (valid_from_issuer) begin
        tail <= next_tail;
        signal[tail] <= signal_from_issuer;
        status[tail] <= 0;
        rd[tail] <= rd_from_issuer;
        supposed_next_pc[tail] <= next_pc_from_issuer;
        pc[tail] <= pc_from_issuer;
      end

      if (dest_from_lsb_bus) begin
        status[dest_from_lsb_bus] <= 1;
        value[dest_from_lsb_bus] <= value_from_lsb_bus;
      end

      if (dest_from_rss_bus) begin
        status[dest_from_rss_bus] <= 1;
        value[dest_from_rss_bus] <= value_from_rss_bus;
        correct_next_pc[dest_from_rss_bus] <= next_pc_from_rss_bus;
      end

      if (signal[head] == `ISSUER_TO_ROB_SIGNAL_STORE) begin
        head <= head == `RO_BUFFER_SIZE ? 1 : head + 1;
        status[head] <= 0;
        signal[head] <= `ISSUER_TO_ROB_SIGNAL_DEFAULT;

        dest_to_reg_file <= 0;
        rd_to_reg_file <= 0;
        value_to_reg_file <= 0;
        dest_to_rob_bus <= head;
        ls_select_to_rob_bus <= 1;
        br_to_rob_bus <= 0;
        is_taken_to_rob_bus <= 0;
      end else if (status[head]) begin
        head <= head == `RO_BUFFER_SIZE ? 1 : head + 1;
        status[head] <= 0;
        signal[head] <= `ISSUER_TO_ROB_SIGNAL_DEFAULT;

        dest_to_reg_file <= head;
        rd_to_reg_file <= rd[head];
        value_to_reg_file <= value[head];
        dest_to_rob_bus <= 0;
        ls_select_to_rob_bus <= 0;

        if (signal[head] == `ISSUER_TO_ROB_SIGNAL_BRANCH) begin
          if (supposed_next_pc[head] != correct_next_pc[head]) begin
            reset_to_rob_bus <= 1;
            next_pc_to_rob_bus <= correct_next_pc[head];
          end
          br_to_rob_bus <= 1;
          is_taken_to_rob_bus <= correct_next_pc[head] != (pc[head] + 4);
          pc_to_rob_bus <= pc[head];
        end else begin
          br_to_rob_bus <= 0;
          is_taken_to_rob_bus <= 0;
        end
      end else if (signal[head] == `ISSUER_TO_ROB_SIGNAL_LOAD) begin
        dest_to_reg_file <= 0;
        rd_to_reg_file <= 0;
        value_to_reg_file <= 0;
        dest_to_rob_bus <= head;
        ls_select_to_rob_bus <= 0;
        br_to_rob_bus <= 0;
        is_taken_to_rob_bus <= 0;
      end else begin
        dest_to_reg_file <= 0;
        rd_to_reg_file <= 0;
        value_to_reg_file <= 0;
        dest_to_rob_bus <= 0;
        ls_select_to_rob_bus <= 0;
        br_to_rob_bus <= 0;
        is_taken_to_rob_bus <= 0;
      end
      size <= size - (signal[head] == `ISSUER_TO_ROB_SIGNAL_STORE || status[head]) + (valid_from_issuer);
    end
  end

endmodule

`endif
