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
    input wire[`REG_TYPE] next_pc_from_issuer, // for branch only
    output wire[`RO_BUFFER_ID_TYPE] dest_to_issuer,

    // for issuer
    input wire[`RO_BUFFER_ID_TYPE] qj_from_issuer,
    output wire valid_of_vj_to_issuer,
    output wire[`REG_TYPE] vj_to_issuer,

    input wire[`RO_BUFFER_ID_TYPE] qk_from_issuer,
    output wire valid_of_vk_to_issuer,
    output wire[`REG_TYPE] vk_to_issuer,

    // for rob bus
    output reg reset_to_rob_bus,
    output reg[`REG_TYPE] pc_to_rob_bus,
    output reg store_to_rob_bus,

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

  reg[`REG_ID_TYPE] status[`RO_BUFFER_TYPE];
  reg[`ISSUER_TO_ROB_SIGNAL_TYPE] signal[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] value[`RO_BUFFER_TYPE];
  reg[`REG_ID_TYPE] rd[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] supposed_next_pc[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] correct_next_pc[`RO_BUFFER_TYPE];

  wire is_any_reset = rst || reset_from_rob_bus;

  assign is_ro_buffer_full = size == `RO_BUFFER_SIZE;
  wire[`RO_BUFFER_ID_TYPE] next_tail = tail == `RO_BUFFER_SIZE_MINUS_1 ? 1 : tail + 1;
  assign dest_to_issuer = valid_from_issuer ? next_tail : tail;

  always @(posedge clk) begin
    if (is_any_reset) begin
      head <= 1;
      tail <= 1;
      size <= 0;
      reset_to_rob_bus <= 0;
      for (integer i = 1; i <= `RO_BUFFER_SIZE_PLUS_1; i++) begin
        signal[i] <= 0;
        status[i] <= 0;
        value[i] <= 0;
        rd[i] <= 0;
        supposed_next_pc[i] <= 0;
        correct_next_pc[i] <= 0;
      end
    end
  end

  always @(posedge clk) begin
    if (!is_any_reset) begin
      if (valid_from_issuer) begin
        tail <= next_tail;
        size <= size + 1;
        signal[tail] <= signal_from_issuer;
        status[tail] <= 0;
        rd[tail] <= rd_from_issuer;
        supposed_next_pc[tail] <= next_pc_from_issuer;
      end
    end
  end

  always @(posedge clk) begin
    if (!is_any_reset) begin
      if (dest_from_lsb_bus) begin
        status[dest_from_lsb_bus] <= 1;
        value[dest_from_lsb_bus] <= value_from_lsb_bus;
      end
      if (dest_from_rss_bus) begin
        status[dest_from_rss_bus] <= 1;
        value[dest_from_rss_bus] <= value_from_rss_bus;
        correct_next_pc[dest_from_rss_bus] <= next_pc_from_rss_bus;
      end
    end
  end

  always @(posedge clk) begin
    if (!is_any_reset) begin
      if (status[head]) begin
        head <= head == `RO_BUFFER_SIZE_MINUS_1 ? 1 : head + 1;
        size <= size - 1;
        if (signal[head] == `ISSUER_TO_ROB_SIGNAL_BRANCH) begin
          dest_to_reg_file <= 0;
          rd_to_reg_file <= 0;
          value_to_reg_file <= 0;
          store_to_rob_bus <= 0;
          if (supposed_next_pc[head] != correct_next_pc[head]) begin
            reset_to_rob_bus <= 1;
            pc_to_rob_bus <= correct_next_pc[head];
          end
        end else if (signal[head] == `ISSUER_TO_ROB_SIGNAL_STORE) begin
          dest_to_reg_file <= 0;
          rd_to_reg_file <= 0;
          value_to_reg_file <= 0;
          store_to_rob_bus <= 1;
        end else begin
          dest_to_reg_file <= head;
          rd_to_reg_file <= rd[head];
          value_to_reg_file <= value[head];
          store_to_rob_bus <= 0;
        end
      end else begin
        dest_to_reg_file <= 0;
        rd_to_reg_file <= 0;
        value_to_reg_file <= 0;
        store_to_rob_bus <= 0;
      end
    end
  end

endmodule

`endif
