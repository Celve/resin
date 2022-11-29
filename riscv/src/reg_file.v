`ifndef REG_FILE_V
`define REG_FILE_V

`include "config.v"

module reg_file(
    input wire clk,
    input wire rst,
    input wire rdy,

    // for issuer's rs
    input wire[`REG_ID_TYPE] rs_from_issuer,
    output wire[`REG_TYPE] vj_to_issuer,
    output wire[`RO_BUFFER_ID_TYPE] qj_to_issuer,

    // for issuer's rt
    input wire[`REG_ID_TYPE] rt_from_issuer,
    output wire[`REG_TYPE] vk_to_issuer,
    output wire[`RO_BUFFER_ID_TYPE] qk_to_issuer,

    // for issuer's rd
    input wire[`REG_ID_TYPE] rd_from_issuer,
    input wire[`RO_BUFFER_ID_TYPE] dest_from_issuer,

    // for ro buffer
    input wire[`RO_BUFFER_ID_TYPE] dest_from_ro_buffer,
    input wire[`REG_ID_TYPE] rd_from_ro_buffer,
    input wire[`REG_TYPE] value_from_ro_buffer,

    // for rob bus
    input wire reset_from_rob_bus
  );


  reg[`REG_TYPE] values[`REG_NUM_TYPE];
  reg[`REG_ID_TYPE] status[`REG_NUM_TYPE];

  wire is_any_reset = rst || reset_from_rob_bus;

  integer i;

  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < `REG_NUM; i = i + 1) begin
        values[i] <= 0;
        status[i] <= 0;
      end
    end else if (reset_from_rob_bus) begin
      for (i = 0; i < `REG_NUM; i = i + 1) begin
        status[i] <= 0;
      end
    end else if (rdy) begin
      if (!reset_from_rob_bus && rd_from_ro_buffer && rd_from_issuer && rd_from_ro_buffer == rd_from_issuer) begin
        values[rd_from_ro_buffer] <= value_from_ro_buffer;
        status[rd_from_issuer] <= dest_from_issuer;
      end else begin
        if (!reset_from_rob_bus && rd_from_issuer) begin
          status[rd_from_issuer] <= dest_from_issuer;
        end

        if (!reset_from_rob_bus && dest_from_ro_buffer == status[rd_from_ro_buffer]) begin
          status[rd_from_ro_buffer] <= 0;
        end
        if (rd_from_ro_buffer) begin
          values[rd_from_ro_buffer] <= value_from_ro_buffer;
        end
      end
    end
  end

  assign qj_to_issuer =
         rd_from_issuer && rd_from_issuer == rs_from_issuer ? dest_from_issuer :
         rd_from_ro_buffer && rd_from_ro_buffer == rs_from_issuer && status[rd_from_ro_buffer] == dest_from_ro_buffer ? 0 : status[rs_from_issuer];

  assign vj_to_issuer =
         rd_from_issuer && rd_from_issuer == rs_from_issuer ? 0 :
         rd_from_ro_buffer && rd_from_ro_buffer == rs_from_issuer && status[rd_from_ro_buffer] == dest_from_ro_buffer ? value_from_ro_buffer :
         status[rs_from_issuer] ? 0 :
         values[rs_from_issuer];

  assign qk_to_issuer =
         rd_from_issuer && rd_from_issuer == rt_from_issuer ? dest_from_issuer :
         rd_from_ro_buffer && rd_from_ro_buffer == rt_from_issuer && status[rd_from_ro_buffer] == dest_from_ro_buffer ? 0 :
         status[rt_from_issuer];

  assign vk_to_issuer =
         rd_from_issuer && rd_from_issuer == rt_from_issuer ? 0 :
         rd_from_ro_buffer && rd_from_ro_buffer == rt_from_issuer && status[rd_from_ro_buffer] == dest_from_ro_buffer ? value_from_ro_buffer :
         status[rt_from_issuer] ? 0 :
         values[rt_from_issuer];

endmodule

`endif
