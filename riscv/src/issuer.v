`ifndef ISSUER_V
`define ISSUER_V

`include "config.v"
`include "decoder.v"

module issuer(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire ready_from_inst_fetcher,
    input wire[`INST_TYPE] inst_from_inst_fetcher);

  wire[`REG_ID_TYPE] rd;
  wire[`REG_ID_TYPE] rs1;
  wire[`REG_ID_TYPE] rs2;
  wire[`IMM_TYPE] imm;

  decoder decoder_0(
            .inst(inst_from_inst_fetcher),
            .rd(rd),
            .rs1(rs1),
            .rs2(rs2),
            .imm(imm));

  always @(posedge clk) begin
    if (ready_from_inst_fetcher) begin
      // $display("rd: %d, rs1: %d, rs2: %d, imm: %h", rd, rs1, rs2, imm);
    end
  end

endmodule

`endif
