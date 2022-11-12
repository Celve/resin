`include "config.v"

module mem_mgmt_unit (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire[7:0] data_from_ram,
    output reg rw_select_to_ram,
    output reg[`ADDR_TYPE] addr_to_ram,
    output reg [7:0] data_to_ram,

    input wire[`ADDR_TYPE] addr_from_icache,
    input wire valid_from_icache,
    output reg[`DATA_TYPE] data_to_icache,
    output reg next_cycle_rdy_to_icache,

    input wire[`ADDR_TYPE] addr_from_dcache,
    input wire[`DATA_TYPE] data_from_dcache,
    input wire valid_from_dcache,
    input wire rw_flag_from_dcache,
    output reg next_cycle_rdy_to_dcache,
    output reg[`DATA_TYPE] data_to_dcache);

  // FIXME: I don't take rdy and rst into consideration currently

  reg[2:0] state;
  reg[2:0] mode;
  reg[`DATA_TYPE] data;

  parameter[2:0] STATE_0 = 0; // idle
  parameter[2:0] STATE_1 = 1; // first byte
  parameter[2:0] STATE_2 = 2; // second byte
  parameter[2:0] STATE_3 = 3; // third byte
  parameter[2:0] STATE_4 = 4; // fourth byte

  parameter[2:0] DEFAULT = 0;
  parameter[2:0] READ_DCACHE = 1;
  parameter[2:0] READ_ICACHE = 2;
  parameter[2:0] WRITE_DCACHE = 3;

  initial begin
    state = STATE_0; // initialize it as idle
    mode = DEFAULT;
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
        state <= STATE_1;
      end

      // ask to obtain the second 8 bits
      STATE_1: begin
        case (mode)
          READ_ICACHE: begin
            data_to_icache[7:0] <= data_from_ram;
            addr_to_ram <= addr_from_icache + 1;
          end

          READ_DCACHE: begin
            data_to_dcache <= data_from_ram;
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
            data_to_icache <= data_from_ram;
            addr_to_ram <= addr_from_icache + 2;
          end

          READ_DCACHE: begin
            data_to_dcache <= data_from_ram;
            addr_to_ram <= addr_from_dcache + 2;
          end

          WRITE_DCACHE: begin
            data <= data[23:16];
            addr_to_ram <= addr_from_dcache + 2;
          end
        endcase
        state <= STATE_3;
      end

      // ask to obtain the fourth 8 bits
      STATE_3: begin
        case (mode)
          READ_ICACHE: begin
            data_to_icache <= data_from_ram;
            addr_to_ram <= addr_from_icache + 3;
            next_cycle_rdy_to_icache <= 1;
          end

          READ_DCACHE: begin
            data_to_dcache <= data_from_ram;
            addr_to_ram <= addr_from_dcache + 3;
            next_cycle_rdy_to_dcache <= 1;
          end

          WRITE_DCACHE: begin
            data <= data[31:17];
            addr_to_ram <= addr_from_dcache + 3;
            next_cycle_rdy_to_dcache <= 1;
          end
        endcase
        state <= STATE_4;
      end

      // preserve the last query, init for the next query (if any)
      STATE_4: begin
        case (mode)
          READ_ICACHE: begin
            data_to_icache <= data_from_ram;
          end

          READ_DCACHE: begin
            data_to_dcache <= data_from_ram;
          end
        endcase

        if (valid_from_icache) begin
          addr_to_ram <= addr_from_icache;
          mode <= READ_ICACHE;
          state <= STATE_1;
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
          state <= STATE_1;
        end
        else begin
          state <= STATE_0;
        end
      end

    endcase
  end
endmodule
