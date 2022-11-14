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
`define ADDR_WIDTH 32
`define CACHE_INDEX_WIDTH 8
`define CACHE_LINE_WIDTH 2

// for instruction fetcher
`define INST_FETCHER_IDLE 0
`define INST_FETCHER_BUSY 1

// for memory controller
`define MEM_CTRLER_PEDING 0
`define MEM_CTRLER_DONE 1

`define MEM_CTRLER_IDLE 0
`define MEM_CTRLER_READING 1
`define MEM_CTRLER_WRITING 2

// for memory management unit
`define MEM_MGMT_UNIT_IDLE 0
`define MEM_MGMT_UNIT_READ_INST 1
`define MEM_MGMT_UNIT_READ_DATA 2
`define MEM_MGMT_UNIT_WRITE 3

// for instruction
`define INST_BYTE_NUM 4


