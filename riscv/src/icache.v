`include "config.v"

module inst_cache(
    input wire clk,
    input wire rst,
    input wire rdy,

    // ports for memory management unit
    output reg valid_to_mem_mgmt_unit,
    output reg[`ADDR_TYPE] addr_to_mem_mgmt_unit,
    input wire next_cycle_ready_from_mem_mgmt_unit,
    input wire[`DATA_TYPE] data_from_mem_mgmt_unit,

    // ports for instruction fetcher
    input wire valid_from_inst_fetcher,
    input wire[`ADDR_TYPE] addr_from_inst_fetcher,
    output reg next_cycle_ready_to_inst_fetcher,
    output reg[`DATA_TYPE] data_to_inst_fetcher);

  reg next_cycle_rdy;

  initial begin
    next_cycle_rdy = 0;
  end

  always @(posedge clk) begin
    // set up to pass informations
    if (valid_from_inst_fetcher) begin
      valid_to_mem_mgmt_unit <= 1;
      addr_to_mem_mgmt_unit <= addr_from_inst_fetcher;
    end
    else begin
      valid_to_mem_mgmt_unit <= 0;
    end

    if (next_cycle_ready_from_mem_mgmt_unit) begin
      next_cycle_ready_to_inst_fetcher <= 1;
    end
    else begin
      next_cycle_ready_to_inst_fetcher <= 0;
    end

    if (next_cycle_rdy) begin
      next_cycle_rdy = 0;
      data_to_inst_fetcher <= data_from_mem_mgmt_unit;
    end
  end

endmodule
