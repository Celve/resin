`include "config.v"

module decoder(
    input wire[`INST_TYPE] inst,
    output wire[`REG_ID_TYPE] rd,
    output wire[`REG_ID_TYPE] rs1,
    output wire[`REG_ID_TYPE] rs2,
    output wire[`IMM_TYPE] imm);

endmodule
