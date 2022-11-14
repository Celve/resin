`include "config.v"

/**
 * Protocol descriptions: 
 * 1. When icache or dcache want to send address to memory management unit, they must set the valid bit to be true.
 * 2. When memory management unit is able to accept another address, it will set the ready bit to be true, only in next cycle.
 */

module mem_mgmt_unit (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire[7:0] data_from_ram,
    output reg rw_select_to_ram,
    output reg[`ADDR_TYPE] addr_to_ram,
    output reg[7:0] data_to_ram,

    input wire[`ADDR_TYPE] addr_from_icache,
    input wire valid_from_icache,
    output reg[`DATA_TYPE] data_to_icache,
    output reg ready_to_icache,

    input wire[`ADDR_TYPE] addr_from_dcache,
    input wire[`DATA_TYPE] data_from_dcache,
    input wire valid_from_dcache,
    input wire rw_flag_from_dcache,
    output reg ready_to_dcache,
    output reg[`DATA_TYPE] data_to_dcache);

  // FIXME: I don't take rdy and rst into consideration currently

  reg[2:0] state;
  reg[2:0] vice_state;
  reg[2:0] mode;
  reg[2:0] vice_mode;
  reg[`DATA_TYPE] data;

  parameter[2:0] STATE_0 = 0; // idle
  parameter[2:0] STATE_1 = 1; // just send
  parameter[2:0] STATE_2 = 2; // first byte
  parameter[2:0] STATE_3 = 3; // second byte, tell cache to send a new one
  parameter[2:0] STATE_4 = 4; // third byte
  parameter[2:0] STATE_5 = 5; // fouth byte

  parameter[2:0] DEFAULT = 0;
  parameter[2:0] READ_DCACHE = 1;
  parameter[2:0] READ_ICACHE = 2;
  parameter[2:0] WRITE_DCACHE = 3;

  initial begin
    state = STATE_0; // initialize it as idle
    mode = DEFAULT;
    ready_to_dcache = 0;
    ready_to_icache = 0;
  end

  always @(posedge clk) begin
    case (state)
      // initialize state machine and ask to obtain the first 8 bits
      STATE_0: begin
        if (valid_from_icache) begin
          addr_to_ram <= addr_from_icache;
          mode <= READ_ICACHE;
        end
        else if (valid_from_dcache) begin
          addr_to_ram <= addr_from_dcache;
          if (rw_flag_from_dcache) begin
            mode <= WRITE_DCACHE;
            data <= data_from_dcache[7:0];
          end
          else begin
            mode <= READ_DCACHE;
          end
        end

        if (valid_from_dcache || valid_from_icache) begin
          state <= STATE_1;
        end
      end

      // ask to obtain the second 8 bits
      STATE_1: begin
        case (mode)
          READ_ICACHE: begin
            // data_to_icache[7:0] <= data_from_ram;
            addr_to_ram <= addr_from_icache + 1;
          end

          READ_DCACHE: begin
            // data_to_dcache[7:0] <= data_from_ram;
            addr_to_ram <= addr_from_dcache + 1;
          end

          WRITE_DCACHE: begin
            data <= data[15:8];
            addr_to_ram <= addr_from_dcache + 1;
          end
        endcase
        state <= STATE_2;
      end

      // ask to obtain the third 8 bits
      STATE_2: begin
        case (mode)
          READ_ICACHE: begin
            // data_to_icache[15:8] <= data_from_ram;
            data_to_icache[7:0] <= data_from_ram;
            addr_to_ram <= addr_from_icache + 2;
            ready_to_icache <= 1;
          end

          READ_DCACHE: begin
            // data_to_dcache[15:8] <= data_from_ram;
            data_to_dcache[7:0] <= data_from_ram;
            addr_to_ram <= addr_from_dcache + 2;
            ready_to_dcache <= 1;
          end

          WRITE_DCACHE: begin
            data <= data[23:16];
            addr_to_ram <= addr_from_dcache + 2;
            ready_to_dcache <= 1;
          end
        endcase
        state <= STATE_3;
      end

      // ask to obtain the fourth 8 bits
      STATE_3: begin
        case (mode)
          READ_ICACHE: begin
            // data_to_icache[23:16] <= data_from_ram;
            data_to_icache[15:8] <= data_from_ram;
            addr_to_ram <= addr_from_icache + 3;
            ready_to_icache <= 0;
            vice_state <= STATE_4;
            vice_mode <= READ_ICACHE;
          end

          READ_DCACHE: begin
            // data_to_dcache[23:16] <= data_from_ram;
            data_to_dcache[15:8] <= data_from_ram;
            addr_to_ram <= addr_from_dcache + 3;
            ready_to_dcache <= 0;
            vice_state <= STATE_4;
            vice_mode <= READ_DCACHE;
          end

          WRITE_DCACHE: begin
            data <= data[31:17];
            addr_to_ram <= addr_from_dcache + 3;
            ready_to_dcache <= 0;
          end
        endcase
        state <= STATE_0;
      end
    endcase
  end

  always @(posedge clk) begin
    case (vice_state)
      STATE_4: begin
        case (mode)
          READ_ICACHE: begin
            data_to_icache[23:16] <= data_from_ram;
          end

          READ_DCACHE: begin
            data_to_dcache[23:16] <= data_from_ram;
          end
        endcase
        vice_state <= STATE_5;
      end

      STATE_5: begin
        case (mode)
          READ_ICACHE: begin
            data_to_icache[31:24] <= data_from_ram;
          end

          READ_DCACHE: begin
            data_to_dcache[31:24] <= data_from_ram;
          end
        endcase
        vice_state <= STATE_0;
        vice_mode <= DEFAULT;
      end
    endcase
  end
endmodule
