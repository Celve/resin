`ifndef INST_FETCHER_V
`define INST_FETCHER_V

`include "config.v"

module inst_fetcher(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire is_any_full,

    // ports for memory management unit
    output reg valid_to_mem_ctrler,
    output reg[`ADDR_TYPE] addr_to_mem_ctrler,
    input wire ready_from_mem_ctrler,
    input wire[`CACHE_LINE_TYPE] cache_line_from_mem_ctrler,

    // ports for issuer
    output wire ready_to_issuer,
    output wire[`REG_TYPE] pc_to_issuer,
    output wire[`REG_TYPE] next_pc_to_issuer,
    output wire[`INST_TYPE] inst_to_issuer,

    // ports for predictor
    output wire[`INST_TYPE] inst_to_br_predictor,
    output wire[`REG_TYPE] pc_to_br_predictor,
    input wire[`REG_TYPE] next_pc_from_br_predictor,

    // ports for rob bus
    input wire reset_from_rob_bus,
    input wire[`REG_TYPE] next_pc_from_rob_bus
  );

  parameter[2:0] IDLE = 0; // instruction fetcher has nothing to do
  parameter[2:0] INTERACTING = 1; // instruction fetcher is interacting with memory management unit
  parameter[2:0] PENDING = 2; // instruction fetcher find out that the next instruction hits, however, the previous one is still in the memory management unit

  reg[`CACHE_TAG_TYPE] cache_tags[`CACHE_SIZE - 1:0];
  reg[`CACHE_LINE_TYPE] cache_lines[`CACHE_SIZE - 1:0];
  reg cache_valid_bits[`CACHE_SIZE - 1:0];
  reg[2:0] state;
  reg[`REG_TYPE] pc;
  wire[`REG_TYPE] next_pc;

  wire[`CACHE_TAG_TYPE] tag = pc[`CACHE_TAG_RANGE];
  wire[`CACHE_INDEX_TYPE] index = pc[`CACHE_INDEX_RANGE];
  wire[`CACHE_OFFSET_TYPE] offset = pc[`CACHE_OFFSET_RANGE] << 3;
  wire hit = cache_valid_bits[index] && cache_tags[index] == tag;

  wire[`INST_TYPE] inst = hit ? cache_lines[index][offset +: 32] : 0;

  assign inst_to_br_predictor = inst;
  assign pc_to_br_predictor = pc;
  assign next_pc = next_pc_from_br_predictor;

  assign ready_to_issuer = hit;
  assign pc_to_issuer = pc;
  assign next_pc_to_issuer = next_pc;
  assign inst_to_issuer = inst;

  integer i, j;

  always @(posedge clk) begin
    // just for reset
    if (rst) begin
      state <= IDLE;
      pc <= 0;
      for (i = 0; i < `CACHE_SIZE; i = i + 1) begin
        cache_valid_bits[i] <= 0;
        cache_tags[i] <= 0;
      end

      valid_to_mem_ctrler <= 0;
      addr_to_mem_ctrler <= 0;
    end else if (rdy) begin
      if (reset_from_rob_bus) begin
        pc <= next_pc_from_rob_bus;
        // next_pc <= pc_from_rob_bus + 4; // lack of prediction
      end else if (hit && !is_any_full) begin
        pc <= next_pc;
      end

      case (state)
        // when it's idle, look at the icache first
        IDLE: begin
          if (!hit && !reset_from_rob_bus) begin
            addr_to_mem_ctrler <= pc;
            valid_to_mem_ctrler <= 1;
            state <= INTERACTING;
          end
        end

        INTERACTING: begin
          if (ready_from_mem_ctrler) begin
            if (pc == addr_to_mem_ctrler) begin
              cache_lines[index] <= cache_line_from_mem_ctrler;
              cache_tags[index] <= tag;
              cache_valid_bits[index] <= 1;
            end
            valid_to_mem_ctrler <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule

`endif
