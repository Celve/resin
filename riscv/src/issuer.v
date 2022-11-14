`include "config.v"

module issuer(
    input wire[`INST_TYPE] inst_from_inst_fetcher);

  wire[`REG_ID_TYPE] rd;
  wire[`REG_ID_TYPE] rs1;
  wire[`REG_ID_TYPE] rs2;
  wire[`IMM_TYPE] imm;

  issuer issuer_0(
           .inst(inst_from_inst_fetcher),
           .rd(rd),
           .rs1(rs1),
           .rs2(rs2));

  always @(posedge clk) begin

  end

endmodule
