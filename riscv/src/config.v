// type
`define REG_TYPE 31:0
`define ADDR_TYPE 16:0
`define INST_TYPE 31:0
`define DATA_TYPE 31:0
`define REG_ID_TYPE 4:0
`define IMM_TYPE 20:0
`define TAG_TYPE `ADDR_WIDTH - `CACHE_INDEX_WIDTH - `CACHE_LINE_WIDTH - 1:0

// sizes
`define INST_CACHE_SIZE 256
`define ADDR_WIDTH 16
`define CACHE_INDEX_WIDTH 8
`define CACHE_LINE_WIDTH 2

// instruction types
`define LUI_INST 0
`define AUIPC_INST 1
`define JAL_INST 2
`define JALR_INST 3
`define BEQ_INST 4
`define BNE_INST 5
`define BLT_INST 6
`define BGE_INST 7
`define BLTU_INST 8
`define BGEU_INST 9
`define LB_INST 10
`define LH_INST 11
`define LW_INST 12
`define LBU_INST 13
`define LHU_INST 14
`define SB_INST 15
`define SH_INST 16
`define SW_INST 17
`define ADDI_INST 18
`define SLTI_INST 19
`define SLTIU_INST 20
`define XORI_INST 21
`define ORI_INST 22
`define ANDI_INST 23
`define SLLI_INST 24
`define SRLI_INST 25
`define SRAI_INST 26
`define ADD_INST 27
`define SUB_INST 28
`define SLL_INST 29
`define SLT_INST 30
`define SLTU_INST 31
`define XOR_INST 32
`define SRL_INST 33
`define SRA_INST 34
`define OR_INST 35
`define AND_INST 36
