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
    output wire[`REG_TYPE] vk_to_issuer

  );

  reg[`RO_BUFFER_ID_TYPE] head; // head is the real head
  reg[`RO_BUFFER_ID_TYPE] tail; // tail - 1 is the real tail
  reg[`RO_BUFFER_ID_TYPE] size;

  reg[`REG_ID_TYPE] status[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] value[`RO_BUFFER_TYPE];
  reg[`REG_ID_TYPE] rd[`RO_BUFFER_TYPE];
  reg[`REG_TYPE] pc[`RO_BUFFER_TYPE];

  assign is_ro_buffer_full = size == `RO_BUFFER_SIZE;
  assign dest_to_issuer = tail;

  always @(posedge clk) begin
    if (rst) begin
      head <= 1;
      tail <= 1;
    end else begin
      if (valid_from_issuer) begin
        tail <= tail == `RO_BUFFER_SIZE_MINUS_1 ? 1 : tail + 1;
        size <= size + 1;
        status[tail] <= 0;
        rd[tail] <= rd_from_issuer;
        pc[tail] <= next_pc_from_issuer;
      end

      // commit
      if (status[head]) begin
        // TODO: commit it
      end
    end
  end


endmodule

`endif
