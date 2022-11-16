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
    input wire[`INST_TYPE] inst_from_mem_ctrler,

    // ports for issuer
    output wire ready_to_issuer,
    output wire[`INST_TYPE] inst_to_issuer);

  parameter[2:0] IDLE = 0; // instruction fetcher has nothing to do
  parameter[2:0] INTERACTING = 1; // instruction fetcher is interacting with memory management unit
  parameter[2:0] PENDING = 2; // instruction fetcher find out that the next instruction hits, however, the previous one is still in the memory management unit

  reg[`TAG_TYPE] cache_tags[`INST_CACHE_SIZE - 1:0];
  reg[`INST_TYPE] cache_lines[`INST_CACHE_SIZE - 1:0];
  reg cache_valid_bits[`INST_CACHE_SIZE - 1:0];
  reg[2:0] state;
  reg[2:0] count;
  reg[`REG_TYPE] prev_pc; // means not sent
  reg[`REG_TYPE] pc; // means fetched
  reg[`REG_TYPE] next_pc; // means next fetched

  wire[`TAG_TYPE] tag = pc[`ADDR_WIDTH - 1:`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH];
  wire[`CACHE_INDEX_WIDTH - 1:0] index = pc[`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH - 1:`CACHE_LINE_WIDTH];

  wire[`TAG_TYPE] next_tag = next_pc[`ADDR_WIDTH - 1:`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH];
  wire[`CACHE_INDEX_WIDTH - 1:0] next_index = next_pc[`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH - 1:`CACHE_LINE_WIDTH];

  wire[`TAG_TYPE] prev_tag = prev_pc[`ADDR_WIDTH - 1:`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH];
  wire[`CACHE_INDEX_WIDTH - 1:0] prev_index = prev_pc[`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH - 1:`CACHE_LINE_WIDTH];

  wire hit = cache_valid_bits[prev_index] && cache_tags[prev_index] == prev_tag;

  assign ready_to_issuer = hit;
  assign inst_to_issuer = hit ? cache_lines[prev_index] : 0;

  always @(posedge clk) begin
    if (hit && !stall) begin
      prev_pc <= pc;
    end

    // just for reset
    if (rst) begin
      state <= IDLE;
      count <= 0;
      prev_pc <= 0;
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
          if (hit) begin
            if (!stall) begin
              pc <= next_pc;
              next_pc <= next_pc == 8 ? 0 : next_pc + 4;
              // next_pc <= next_pc + 4; // TODO: predict pc
            end
          end else begin
            addr_to_mem_ctrler <= pc;
            valid_to_mem_ctrler <= 1;
            state <= INTERACTING;
          end

        end

        INTERACTING: begin
          if (ready_from_mem_ctrler) begin
            count <= 3;

            // maybe the next pc isn't cached
            // or else it's cached, the state has to be set to pending because it would not access memory in the next round
            if (!cache_valid_bits[next_index] || cache_tags[next_index] != next_tag || addr_to_mem_ctrler == pc) begin // 看看两次间隔规律来推断这个会在count=1多久以后出现，可能这个在stall不能传
              addr_to_mem_ctrler <= next_pc;
              valid_to_mem_ctrler <= 1;
            end else begin
              state <= PENDING;
              valid_to_mem_ctrler <= 0;
            end
          end
        end
      endcase

      // wait two cycles to fetch inst from inst fetcher
      case (count)
        3: begin
          count <= 2;
        end

        2: begin
          count <= 1;
        end

        // after this, it would go to IDLE or INTERACTING
        // therefore I only need to set rdy to 0 in these two states
        1: begin
          count <= 0;
          cache_lines[index] <= inst_from_mem_ctrler;
          cache_tags[index] <= prev_tag;
          cache_valid_bits[index] <= 1;

          // because the next inst is ought to be fetched from icache
          if (!stall) begin
            pc <= next_pc;
            next_pc <= next_pc == 8 ? 0 : next_pc + 4;
            // next_pc <= next_pc + 4; // TODO: predict pc
            if (state == PENDING) begin
              state <= IDLE;
            end
          end else begin
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule

`endif
