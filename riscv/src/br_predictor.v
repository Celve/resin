`ifndef BR_PREDICTOR_V
`define BR_PREDICTOR_V

`include "config.v"

module br_predictor(
    input wire clk,
    input wire rst,
    input wire rdy,

    // for ro_buffer
    input wire valid_from_rob_bus,
    input wire[`BH_TABLE_ID_TYPE] pc_from_rob_bus,
    input wire is_taken_from_rob_bus,

    // for issuer
    input wire[`INST_TYPE] inst_from_inst_fetcher,
    input wire[`REG_TYPE] pc_from_inst_fetcher,
    output wire[`REG_TYPE] next_pc_to_inst_fetcher
  );

  reg[1:0] bh_table[`BRANCH_HISTORY_TABLE_TYPE];
  wire[`BH_TABLE_ID_TYPE] bh_table_index_for_inst_fetcher = pc_from_inst_fetcher & `BRANCH_HISTORY_TABLE_SIZE_MINUS_1;
  wire[`BH_TABLE_ID_TYPE] bh_table_index_for_ro_buffer = pc_from_rob_bus;
  wire[`INST_TYPE] inst = inst_from_inst_fetcher;
  wire[6:0] opcode = inst[`OPCODE_RANGE];

  wire[`IMM_TYPE] jal_offset = {{12{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
  wire[`IMM_TYPE] b_offset = {{20{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};

  assign next_pc_to_inst_fetcher =
         opcode == 7'b1101111 ? pc_from_inst_fetcher + jal_offset :
         opcode != 7'b1100011 ? pc_from_inst_fetcher + 4 :
         bh_table[bh_table_index_for_inst_fetcher] > 1 ? pc_from_inst_fetcher + b_offset :
         pc_from_inst_fetcher + 4;

  integer i;

  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < `BRANCH_HISTORY_TABLE_SIZE; i = i + 1) begin
        bh_table[i] = 0;
      end
    end else if (rdy) begin
      if (valid_from_rob_bus) begin
        if (is_taken_from_rob_bus) begin
          if (bh_table[bh_table_index_for_ro_buffer] != 3) begin
            bh_table[bh_table_index_for_ro_buffer] <= bh_table[bh_table_index_for_ro_buffer] + 1;
          end
        end else begin
          if (bh_table[bh_table_index_for_ro_buffer]) begin
            bh_table[bh_table_index_for_ro_buffer] <= bh_table[bh_table_index_for_ro_buffer] - 1;
          end
        end
      end
    end
  end

endmodule

`endif
