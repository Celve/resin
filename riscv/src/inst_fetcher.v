`ifndef INST_FETCHER_V
`define INST_FETCHER_V

`include "config.v"

module inst_fetcher(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire stall,

    // ports for memory management unit
    output reg valid_to_mem_ctrler,
    output reg[`ADDR_TYPE] addr_to_mem_ctrler,
    input wire ready_from_mem_ctrler,
    input wire[`CACHE_LINE_TYPE] cache_line_from_mem_ctrler,

    // ports for issuer
    output wire ready_to_issuer,
    output wire[`INST_TYPE] inst_to_issuer);

  parameter[2:0] IDLE = 0; // instruction fetcher has nothing to do
  parameter[2:0] INTERACTING = 1; // instruction fetcher is interacting with memory management unit
  parameter[2:0] PENDING = 2; // instruction fetcher find out that the next instruction hits, however, the previous one is still in the memory management unit

  reg[`CACHE_TAG_TYPE] cache_tags[`INST_CACHE_SIZE - 1:0];
  reg[`CACHE_LINE_TYPE] cache_lines[`INST_CACHE_SIZE - 1:0];
  reg cache_valid_bits[`INST_CACHE_SIZE - 1:0];
  reg[2:0] state;
  reg[`REG_TYPE] pc; // means fetched
  reg[`REG_TYPE] next_pc; // means next fetched

  wire[`CACHE_TAG_TYPE] tag = pc[`CACHE_TAG_RANGE];
  wire[`CACHE_INDEX_TYPE] index = pc[`CACHE_INDEX_RANGE];
  wire[`CACHE_OFFSET_TYPE] offset = pc[`CACHE_OFFSET_RANGE];

  wire hit = cache_valid_bits[index] && cache_tags[index] == tag;

  assign ready_to_issuer = hit;
  assign inst_to_issuer = hit ? cache_lines[index][offset +: 32] : 0;

  always @(posedge clk) begin
    if (hit && !stall) begin
      pc <= next_pc;
      next_pc <= next_pc + 4;
    end

    // just for reset
    if (rst) begin
      state <= IDLE;
      pc <= 0;
      next_pc <= 4;
      for (integer i = 0; i < `INST_CACHE_SIZE; i = i + 1) begin
        cache_valid_bits[i] <= 0;
        cache_tags[i] <= 0;
        cache_lines[i] <= 0;
      end
    end else begin
      case (state)
        // when it's idle, look at the icache first
        IDLE: begin
          if (!hit) begin
            addr_to_mem_ctrler <= pc;
            valid_to_mem_ctrler <= 1;
            state <= INTERACTING;
          end
        end

        INTERACTING: begin
          if (ready_from_mem_ctrler) begin
            cache_lines[index] <= cache_line_from_mem_ctrler;
            cache_tags[index] <= tag;
            cache_valid_bits[index] <= 1;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule

`endif
