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
    input wire[`RO_BUFFER_ID_TYPE] dest_from_issuer);


  reg[`REG_TYPE] values[`REG_NUM_TYPE];
  reg[`REG_ID_TYPE] status[`REG_NUM_TYPE];

  always @(posedge clk) begin
    if (rst) begin
      for (integer i = 0; i < `REG_NUM; i = i + 1) begin
        values[i] <= 0;
        status[i] <= 0;
      end
    end
  end

  always @(posedge clk) begin
    if (!rst) begin
      if (rd_from_issuer) begin
        status[rd_from_issuer] <= dest_from_issuer;
      end
    end
  end


  assign qj_to_issuer = status[rs_from_issuer];
  assign vj_to_issuer = status[rs_from_issuer] ? 0 : values[rs_from_issuer];

  assign qk_to_issuer = status[rt_from_issuer];
  assign vk_to_issuer = status[rt_from_issuer] ? 0 : values[rt_from_issuer];
endmodule

`endif
