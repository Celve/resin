`include "config.v"

module instruction_fetcher (
    input wire clk,
    input wire rst,
    input wire rdy,

    output reg valid_to_icache,
    output reg[`ADDR_TYPE] addr_to_icache,
    input wire next_cycle_ready_from_icache,
    input wire[`INST_TYPE] data_from_icache);

  // some constants
  parameter[2:0] IDLE = 0;
  parameter[2:0] FETCH = 1;

  // definition of register pc
  reg[`REG_TYPE] pc;

  reg[2:0] state;
  reg next_cycle_ready;

  initial begin
    state = IDLE;
    next_cycle_ready = 0;
  end

  always @(posedge clk) begin
    case (state)
      IDLE: begin
        valid_to_icache <= 1;
        addr_to_icache <= pc;
        pc <= pc + 4;
        state <= FETCH;
      end

      FETCH: begin
        if (next_cycle_ready_from_icache) begin
          addr_to_icache <= pc;
          pc <= pc + 4;
          valid_to_icache <= 1;
        end
        if (next_cycle_ready) begin
          $display("%d", data_from_icache);
        end
      end
    endcase
  end

endmodule
