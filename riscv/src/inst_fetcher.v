`ifndef INST_FETCHER_V
`define INST_FETCHER_V

`include "config.v"

module inst_fetcher(
    input wire clk,
    input wire rst,
    input wire rdy,

    // ports for memory management unit
    output reg valid_to_mem_mgmt_unit,
    output reg[`ADDR_TYPE] addr_to_mem_mgmt_unit,
    input wire ready_from_mem_mgmt_unit,
    input wire[`INST_TYPE] inst_from_mem_mgmt_unit,

    // ports for issuer
    output reg rdy_to_issuer,
    output reg[`INST_TYPE] inst_to_issuer);

  parameter[2:0] IDLE = 0; // instruction fetcher has nothing to do
  parameter[2:0] INTERACTING = 1; // instruction fetcher is interacting with memory management unit
  parameter[2:0] PENDING = 2; // instruction fetcher find out that the next instruction hits, however, the previous one is still in the memory management unit

  reg[`TAG_TYPE] cache_tags[`INST_CACHE_SIZE - 1:0];
  reg[`INST_TYPE] cache_lines[`INST_CACHE_SIZE - 1:0];
  reg cache_valid_bits[`INST_CACHE_SIZE - 1:0];
  reg[2:0] state;
  reg[2:0] count;
  reg[`REG_TYPE] pc;
  reg[`REG_TYPE] next_pc;

  wire[`TAG_TYPE] tag = pc[`ADDR_WIDTH - 1:`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH];
  wire[`CACHE_INDEX_WIDTH - 1:0] index = pc[`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH - 1:`CACHE_LINE_WIDTH];

  wire[`TAG_TYPE] next_tag = next_pc[`ADDR_WIDTH - 1:`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH];
  wire[`CACHE_INDEX_WIDTH - 1:0] next_index = next_pc[`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH - 1:`CACHE_LINE_WIDTH];

  always @(posedge clk) begin
    // just for reset
    if (rst) begin
      state = IDLE;
      count = 0;
      pc = 0;
      next_pc = 4;
      for (integer i = 0; i < `INST_CACHE_SIZE; i = i + 1) begin
        cache_valid_bits[i] <= 0;
        cache_tags[i] <= 0;
        cache_lines[i] <= 0;
      end
    end

    case (state)
      // when it's idle, look at the icache first
      IDLE: begin
        if (cache_valid_bits[index] && cache_tags[index] == tag) begin
          inst_to_issuer <= cache_lines[index];
          rdy_to_issuer <= 1;
          pc <= next_pc;
          next_pc <= next_pc + 4; // TODO: predict pc
        end else begin
          addr_to_mem_mgmt_unit <= pc;
          valid_to_mem_mgmt_unit <= 1;
          state <= INTERACTING;
          rdy_to_issuer <= 0;
        end

      end

      INTERACTING: begin
        if (ready_from_mem_mgmt_unit) begin
          count <= 3;

          // maybe the next pc isn't cached
          // or else it's cached, the state has to be set to pending because it would not access memory in the next round
          if (!cache_valid_bits[next_index] || cache_tags[next_index] != next_tag) begin
            addr_to_mem_mgmt_unit <= next_pc;
            valid_to_mem_mgmt_unit <= 1;
          end else begin
            state <= PENDING;
            valid_to_mem_mgmt_unit <= 0;
          end
        end


      end
    endcase
  end

  always @(posedge clk) begin
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
        inst_to_issuer <= inst_from_mem_mgmt_unit;
        rdy_to_issuer <= 1;
        count <= 0;
        cache_lines[index] <= inst_from_mem_mgmt_unit;
        cache_tags[index] <= tag;
        cache_valid_bits[index] <= 1;

        // because the next inst is ought to be fetched from icache
        if (state == PENDING) begin
          state <= IDLE;
        end

        // only at this time can we switch the pc
        // the conversion of pc means the stage switching
        pc <= next_pc;
        next_pc <= next_pc + 4; // TODO: predict pc
      end

      0: begin
        if (state == INTERACTING) begin
          rdy_to_issuer <= 0;
        end
      end
    endcase
  end

  // wait two cycles to fetch inst from inst fetcher
endmodule

`endif
