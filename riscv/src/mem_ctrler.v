`ifndef MEM_CTRLER_V
`define MEM_CTRLER_V

`include "config.v"

/**
 * Protocol descriptions: 
 * 1. When icache or dcache want to send address to memory management unit, they must set the valid bit to be true.
 * 2. When memory management unit is able to accept another address, it will set the ready bit to be true, only in next cycle.
 */

module mem_ctrler (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire is_io_buffer_full,

    input wire[7:0] data_from_ram,
    output reg rw_select_to_ram,
    output reg[`ADDR_TYPE] addr_to_ram,
    output reg[7:0] data_to_ram,

    input wire[`ADDR_TYPE] addr_from_icache,
    input wire valid_from_icache,
    output reg[`CACHE_LINE_TYPE] data_to_icache,
    output reg ready_to_icache,

    input wire[`ADDR_TYPE] addr_from_dcache,
    input wire[`CACHE_LINE_TYPE] data_from_dcache,
    input wire valid_from_dcache,
    input wire rw_flag_from_dcache,
    output reg ready_to_dcache,
    output reg[`CACHE_LINE_TYPE] data_to_dcache,

    input wire valid_from_io,
    input wire[`ADDR_TYPE] addr_from_io,
    input wire[`BYTE_TYPE] data_from_io,
    input wire rw_flag_from_io,
    output reg ready_to_io,
    output reg[`BYTE_TYPE] data_to_io
  );

  reg[3:0] state; // 0 means idle, 1 means fetching the first byte, etc.
  reg[2:0] vice_state;
  reg[2:0] mode;
  reg[2:0] vice_mode;
  wire[`CACHE_TAG_AND_INDEX_TYPE] half_addr_from_icache = addr_from_icache[`CACHE_TAG_AND_INDEX_RANGE];
  wire[`CACHE_TAG_AND_INDEX_TYPE] half_addr_from_dcache = addr_from_dcache[`CACHE_TAG_AND_INDEX_RANGE];

  parameter[2:0] DEFAULT = 0;
  parameter[2:0] READ_ICACHE = 1;
  parameter[2:0] READ_DCACHE = 2;
  parameter[2:0] WRITE_DCACHE = 3;
  parameter[2:0] READ_IO = 4;
  parameter[2:0] WRITE_IO = 5;

  always @(posedge clk) begin
    if (rst) begin
      state <= 0; // initialize it as idle
      vice_state <= 0;
      mode <= DEFAULT;
      vice_mode <= DEFAULT;

      ready_to_dcache <= 0;
      data_to_dcache <= 0;
      ready_to_icache <= 0;
      data_to_icache <= 0;
      ready_to_io <= 0;
      data_to_io <= 0;
    end else if (rdy) begin
      // calculate addr
      if (state != 0) begin
        if (mode != WRITE_IO && mode != READ_IO) begin
          case (mode)
            READ_ICACHE: addr_to_ram <= {half_addr_from_icache, state};
            READ_DCACHE, WRITE_DCACHE: addr_to_ram <= {half_addr_from_dcache, state};
          endcase
          state <= state + 1;
        end
      end

      if (ready_to_dcache || ready_to_icache || ready_to_io) begin
        ready_to_icache <= 0;
        ready_to_dcache <= 0;
        ready_to_io <= 0;
        vice_mode <= 0;
      end

      case (state)
        0: begin
          if (valid_from_io) begin
            if (!vice_mode) begin
              rw_select_to_ram <= rw_flag_from_io;
              if (addr_to_ram >= `IO_THRESHOLD) begin
                addr_to_ram <= 0;
              end else if (!rw_flag_from_io) begin
                addr_to_ram <= addr_from_io;
                vice_state <= 1;
                vice_mode <= READ_IO;
              end else if (!is_io_buffer_full) begin // when it's full, we should stall
                addr_to_ram <= addr_from_io;
                data_to_ram <= data_from_io;
                vice_mode <= WRITE_IO;
                ready_to_io <= 1;
              end
            end
          end else if (valid_from_icache && vice_mode != READ_ICACHE) begin
            addr_to_ram <= {half_addr_from_icache, state};
            rw_select_to_ram <= 0;
            state <= 1;
            mode <= READ_ICACHE;
          end else if (valid_from_dcache && vice_mode != READ_DCACHE && vice_mode != WRITE_DCACHE) begin
            addr_to_ram <= {half_addr_from_dcache, state};
            rw_select_to_ram <= rw_flag_from_dcache;
            data_to_ram <= data_from_dcache[`BYTE_0];
            state <= 1;
            mode <= rw_flag_from_dcache ? WRITE_DCACHE : READ_DCACHE;
          end
        end

        1: begin
          case (mode)
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_1];
          endcase
        end

        2: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_0] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_0] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_2];
          endcase
        end

        3: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_1] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_1] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_3];
          endcase
        end

        4: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_2] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_2] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_4];
          endcase
        end

        5: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_3] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_3] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_5];
          endcase
        end

        6: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_4] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_4] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_6];
          endcase
        end

        7: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_5] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_5] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_7];
          endcase
        end

        8: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_6] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_6] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_8];
          endcase
        end

        9: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_7] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_7] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_9];
          endcase
        end

        10: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_8] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_8] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_10];
          endcase
        end

        11: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_9] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_9] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_11];
          endcase
        end

        12: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_10] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_10] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_12];
          endcase
        end

        13: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_11] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_11] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_13];
          endcase
        end

        14: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_12] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_12] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_14];
          endcase
        end

        15: begin
          case (mode)
            READ_ICACHE: data_to_icache[`BYTE_13] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_13] <= data_from_ram;
            WRITE_DCACHE: data_to_ram <= data_from_dcache[`BYTE_15];
          endcase

          vice_mode <= mode;
          if (mode != WRITE_DCACHE) begin
            vice_state <= 1;
          end else begin
            ready_to_dcache <= 1;
          end
        end
      endcase

      case (vice_state)
        1: begin
          case (vice_mode)
            READ_ICACHE: data_to_icache[`BYTE_14] <= data_from_ram;
            READ_DCACHE: data_to_dcache[`BYTE_14] <= data_from_ram;
          endcase
          vice_state <= 2;
        end

        2: begin
          case (vice_mode)
            READ_ICACHE: begin
              data_to_icache[`BYTE_15] <= data_from_ram;
              ready_to_icache <= 1;
              vice_state <= 0;
            end
            READ_DCACHE: begin
              data_to_dcache[`BYTE_15] <= data_from_ram;
              ready_to_dcache <= 1;
              vice_state <= 0;
            end
            READ_IO: begin
              data_to_io <= data_from_ram;
              if (addr_to_ram < `CLK_THRESHOLD || data_from_ram < 224) begin
                vice_state <= 0;
                ready_to_io <= 1;
              end
            end
          endcase
        end
      endcase
    end
  end
endmodule

`endif
