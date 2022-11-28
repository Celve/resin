`ifndef AL_UNIT_V
`define AL_UNIT_V

`include "config.v"

module al_unit(
    input wire[`OP_TYPE] op,
    input wire[`REG_TYPE] rs,
    input wire[`REG_TYPE] rt,
    input wire[`REG_TYPE] pc,
    input wire[`REG_TYPE] imm,
    output reg valid,
    output reg[`REG_TYPE] value, // there are two output ports because of jalr!
    output reg[`REG_TYPE] next_pc);

  always @(*) begin
    // TODO:
    // I don't know how to deal with branch yet
    // therefore branch inst would not appear in here
    valid = 0;
    value = 0;
    next_pc = 0;
    case(op)
      `LUI_INST: value = imm << 12;
      `AUIPC_INST: value = pc + (imm << 12);

      `JAL_INST: begin
        value = pc + 4;
        next_pc = pc + imm;
      end

      `JALR_INST: begin
        next_pc = ($signed(rs) + $signed(imm)) & 32'hFFFFFFFE;
        value = pc + 4;
      end

      `BEQ_INST: next_pc = ($signed(rs) == $signed(rt)) ? pc + $signed(imm) : pc + 4;
      `BNE_INST: next_pc = ($signed(rs) != $signed(rt)) ? pc + $signed(imm) : pc + 4;
      `BLT_INST: next_pc = ($signed(rs) < $signed(rt)) ? pc + $signed(imm) : pc + 4;
      `BGE_INST: next_pc = ($signed(rs) >= $signed(rt)) ? pc + $signed(imm) : pc + 4;
      `BLTU_INST: next_pc = (rs < rt) ? pc + $signed(imm) : pc + 4;
      `BGEU_INST: next_pc = (rs >= rt) ? pc + $signed(imm) : pc + 4;
      `ADDI_INST: value = rs + imm;
      `SLTI_INST: value = $signed(rs) < $signed(imm);
      `SLTIU_INST: value = rs < imm;
      `XORI_INST: value = rs ^ imm;
      `ORI_INST: value = rs | imm;
      `ANDI_INST: value = rs & imm;
      `SLLI_INST: value = rs << imm;
      `SRLI_INST: value = rs >> imm;
      `SRAI_INST: value = $signed(rs) >> imm;
      `ADD_INST: value = rs + rt;
      `SUB_INST: value = rs - rt;
      `SLL_INST: value = rs << rt; // TODO: should I & 0x1f?
      `SLT_INST: value = $signed(rs) < $signed(rt);
      `SLTU_INST: value = rs < rt;
      `XOR_INST: value = rs ^ rt;
      `SRL_INST: value = rs >> rt; // TODO: should I & 0x1f?
      `SRA_INST: value = $signed(rs) >> rt; // TODO: should I & 0x1f?
      `OR_INST: value = rs | rt;
      `AND_INST: value = rs & rt;
      default: value = 0;
    endcase
    valid = 1;
  end

endmodule

`endif
