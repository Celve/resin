`ifndef DECODER_V
`define DECODER_V

`include "config.v"

module decoder(
    input wire[`INST_TYPE] inst,
    output reg[5:0] inst_type,
    output reg[`REG_ID_TYPE] rd,
    output reg[`REG_ID_TYPE] rs1,
    output reg[`REG_ID_TYPE] rs2,
    output reg[`IMM_TYPE] imm);

  wire[6:0] opcode = inst[6:0];

  always @(*) begin
    case (opcode)
      7'b0110111: begin // LUI
        rd = inst[11:7];
        rs1 = 5'b00000;
        rs2 = 5'b00000;
        imm = inst[31:12];
        inst_type = `LUI_INST;
      end

      7'b0010111: begin // AUIPC
        rd = inst[11:7];
        rs1 = 5'b00000;
        rs2 = 5'b00000;
        imm = inst[31:12];
        inst_type = `AUIPC_INST;
      end

      7'b1101111: begin // JAL
        rd = inst[11:7];
        rs1 = 5'b00000;
        rs2 = 5'b00000;
        imm = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
        inst_type = `JAL_INST;
      end

      7'b1100111: begin // JALR
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = 5'b00000;
        imm = {inst[31:20], 1'b0};
        inst_type = `JALR_INST;
      end

      7'b1100011: begin // B-type
        rd = 5'b00000;
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        imm = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};

        case (inst[14:12])
          3'b000: inst_type = `BEQ_INST;
          3'b001: inst_type = `BNE_INST;
          3'b100: inst_type = `BLT_INST;
          3'b101: inst_type = `BGE_INST;
          3'b110: inst_type = `BLTU_INST;
          3'b111: inst_type = `BGEU_INST;
        endcase
      end

      7'b0000011: begin // I-type
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = 5'b00000;
        imm = inst[31:20];

        case (inst[14:12])
          3'b000: inst_type = `LB_INST;
          3'b001: inst_type = `LH_INST;
          3'b010: inst_type = `LW_INST;
          3'b100: inst_type = `LBU_INST;
          3'b101: inst_type = `LHU_INST;
        endcase
      end

      7'b0100011: begin // S-type
        rd = 5'b00000;
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        imm = {inst[31:25], inst[11:7]};

        case (inst[14:12])
          3'b000: inst_type = `SB_INST;
          3'b001: inst_type = `SH_INST;
          3'b010: inst_type = `SW_INST;
        endcase
      end

      7'b0010011: begin // I-type FIXME: buggy because of shamt
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = 5'b00000;
        imm = inst[31:20];

        case(inst[14:12])
          3'b000: inst_type = `ADDI_INST;
          3'b010: inst_type = `SLTI_INST;
          3'b011: inst_type = `SLTIU_INST;
          3'b100: inst_type = `XORI_INST;
          3'b110: inst_type = `ORI_INST;
          3'b111: inst_type = `ANDI_INST;
          3'b001: begin
            case (inst[30:25])
              6'b000000: inst_type = `SLLI_INST;
              6'b010000: inst_type = `SRLI_INST;
              6'b010000: inst_type = `SRAI_INST;
            endcase
            imm = inst[24:20];
          end
        endcase

      end

      7'b0110011: begin // R-type FIXME: might be buggy
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        imm = 1'b0;
        case (inst[14:12])
          3'b000: begin
            case (inst[30:25])
              6'b000000: inst_type = `ADD_INST;
              6'b010000: inst_type = `SUB_INST;
            endcase
          end

          3'b001: inst_type = `SLL_INST;
          3'b010: inst_type = `SLT_INST;
          3'b011: inst_type = `SLTIU_INST;
          3'b100: inst_type = `XOR_INST;

          3'b101: begin
            case (inst[30:25])
              6'b000000: inst_type = `SRL_INST;
              6'b010000: inst_type = `SRA_INST;
            endcase
          end

          3'b110: inst_type = `OR_INST;
          3'b111: inst_type = `AND_INST;
        endcase
      end
    endcase
  end

endmodule

`endif
