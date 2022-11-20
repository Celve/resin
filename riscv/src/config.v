// type
`define REG_TYPE 31:0
`define ADDR_TYPE 16:0
`define INST_TYPE 31:0
`define CACHE_LINE_TYPE 127:0
`define REG_ID_TYPE 4:0
`define BYTE_TYPE 7:0
`define IMM_TYPE 31:0
`define CACHE_TAG_TYPE `ADDR_WIDTH - `CACHE_INDEX_WIDTH - `CACHE_LINE_WIDTH - 1:0
`define CACHE_TAG_AND_INDEX_TYPE `ADDR_WIDTH - `CACHE_LINE_WIDTH - 1:0
`define CACHE_INDEX_TYPE `CACHE_INDEX_WIDTH - 1:0
`define CACHE_OFFSET_TYPE `CACHE_LINE_WIDTH - 1:0
`define RESERVATION_STATION_TYPE `RESERVATION_STATION_SIZE:1
`define LOAD_STORE_BUFFER_TYPE `LOAD_STORE_BUFFER_SIZE:1
`define RO_BUFFER_TYPE `RO_BUFFER_SIZE:1
`define OP_TYPE 5:0
`define REG_NUM_TYPE `REG_NUM - 1:0
`define RO_BUFFER_ID_TYPE 4:0
`define RES_STATION_ID_TYPE 4:0
`define LS_BUFFER_ID_TYPE 4:0
`define ISSUER_TO_ROB_SIGNAL_TYPE 1:0

// ISSUER_TO_ROB_SIGNAL
`define ISSUER_TO_ROB_SIGNAL_NORMAL 0
`define ISSUER_TO_ROB_SIGNAL_STORE 1
`define ISSUER_TO_ROB_SIGNAL_BRANCH 2

// sizes
`define INST_CACHE_SIZE 256
`define ADDR_WIDTH 16
`define CACHE_INDEX_WIDTH 8
`define CACHE_LINE_WIDTH 4
`define RO_BUFFER_SIZE_MINUS_1 15
`define RO_BUFFER_SIZE 16
`define RO_BUFFER_SIZE_PLUS_1 17
`define RESERVATION_STATION_SIZE_MINUS_1 15
`define RESERVATION_STATION_SIZE 16
`define RESERVATION_STATION_SIZE_PLUS_1 17
`define LOAD_STORE_BUFFER_SIZE_MINUS_1 15
`define LOAD_STORE_BUFFER_SIZE 16
`define LOAD_STORE_BUFFER_SIZE_PLUS_1 17
`define REG_NUM 32

// caches
`define CACHE_TAG_RANGE `ADDR_WIDTH - 1:`CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH
`define CACHE_INDEX_RANGE `CACHE_INDEX_WIDTH + `CACHE_LINE_WIDTH - 1:`CACHE_LINE_WIDTH
`define CACHE_OFFSET_RANGE `CACHE_LINE_WIDTH - 1:0
`define CACHE_TAG_AND_INDEX_RANGE `ADDR_WIDTH - 1:`CACHE_LINE_WIDTH

// utils
`define BYTE_0 7:0
`define BYTE_1 15:8
`define BYTE_2 23:16
`define BYTE_3 31:24
`define BYTE_4 39:32
`define BYTE_5 47:40
`define BYTE_6 55:48
`define BYTE_7 63:56
`define BYTE_8 71:64
`define BYTE_9 79:72
`define BYTE_10 87:80
`define BYTE_11 95:88
`define BYTE_12 103:96
`define BYTE_13 111:104
`define BYTE_14 119:112
`define BYTE_15 127:120

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
