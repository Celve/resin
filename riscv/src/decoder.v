`ifndef DECODER_V
`define DECODER_V

`include "config.v"

module decoder(
    input wire[`INST_TYPE] inst,
    output reg[`OP_TYPE] op,
    output reg[`REG_ID_TYPE] rd,
    output reg[`REG_ID_TYPE] rs1,
    output reg[`REG_ID_TYPE] rs2,
    output reg[`IMM_TYPE] imm,

    // some enhancements
    output reg is_load_or_store,
    output reg is_store,
    output reg is_branch);

  wire[6:0] opcode = inst[`OPCODE_RANGE];

  always @(*) begin
    is_load_or_store = 0;
    is_store = 0;
    is_branch = 0;
    op = 0;
    case (opcode)
      7'b0110111: begin // LUI
        rd = inst[11:7];
        rs1 = 5'b00000;
        rs2 = 5'b00000;
        imm = {12'b0, inst[31:12]};
        op = `LUI_INST;
      end

      7'b0010111: begin // AUIPC
        rd = inst[11:7];
        rs1 = 5'b00000;
        rs2 = 5'b00000;
        imm = {12'b0, inst[31:12]};
        op = `AUIPC_INST;
      end

      7'b1101111: begin // JAL
        rd = inst[11:7];
        rs1 = 5'b00000;
        rs2 = 5'b00000;
        imm = {{12{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
        op = `JAL_INST;
        is_branch = 1;
      end

      7'b1100111: begin // JALR
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = 5'b00000;
        imm = {{20{inst[31]}}, inst[31:20], 1'b0};
        op = `JALR_INST;
        is_branch = 1;
      end

      7'b1100011: begin // B-type
        rd = 5'b00000;
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        imm = {{20{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
        is_branch = 1;

        case (inst[14:12])
          3'b000: op = `BEQ_INST;
          3'b001: op = `BNE_INST;
          3'b100: op = `BLT_INST;
          3'b101: op = `BGE_INST;
          3'b110: op = `BLTU_INST;
          3'b111: op = `BGEU_INST;
        endcase
      end

      7'b0000011: begin // L-type
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = 5'b00000;
        imm = {{20{inst[31]}}, inst[31:20]};
        is_load_or_store = 1;

        case (inst[14:12])
          3'b000: op = `LB_INST;
          3'b001: op = `LH_INST;
          3'b010: op = `LW_INST;
          3'b100: op = `LBU_INST;
          3'b101: op = `LHU_INST;
        endcase
      end

      7'b0100011: begin // S-type
        rd = 5'b00000;
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
        is_load_or_store = 1;
        is_store = 1;

        case (inst[14:12])
          3'b000: op = `SB_INST;
          3'b001: op = `SH_INST;
          3'b010: op = `SW_INST;
        endcase
      end

      7'b0010011: begin // I-type FIXME: buggy because of shamt
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = 5'b00000;
        imm = {{20{inst[31]}}, inst[31:20]};

        case(inst[14:12])
          3'b000: op = `ADDI_INST;
          3'b010: op = `SLTI_INST;
          3'b011: op = `SLTIU_INST;
          3'b100: op = `XORI_INST;
          3'b110: op = `ORI_INST;
          3'b111: op = `ANDI_INST;
          3'b001: begin
            op = `SLLI_INST;
            imm = inst[24:20];
          end
          3'b101: begin
            case (inst[31:25])
              7'b0000000: op = `SRLI_INST;
              7'b0100000: op = `SRAI_INST;
            endcase
            imm = inst[24:20];
          end
        endcase

      end

      7'b0110011: begin // R-type FIXME: might be buggy
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        imm = 32'b0;
        case (inst[14:12])
          3'b000: begin
            case (inst[31:25])
              7'b0000000: op = `ADD_INST;
              7'b0100000: op = `SUB_INST;
            endcase
          end

          3'b001: op = `SLL_INST;
          3'b010: op = `SLT_INST;
          3'b011: op = `SLTU_INST;
          3'b100: op = `XOR_INST;

          3'b101: begin
            case (inst[30:25])
              7'b0000000: op = `SRL_INST;
              7'b0100000: op = `SRA_INST;
            endcase
          end

          3'b110: op = `OR_INST;
          3'b111: op = `AND_INST;
        endcase
      end

      default: begin
        rd = 0;
        rs1 = 0;
        rs2 = 0;
        imm = 0;
        op = 0;
      end
    endcase
  end

endmodule

`endif
