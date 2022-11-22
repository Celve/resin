`ifndef NEW_LS_BUFFER_V
`define NEW_LS_BUFFER_V

`include "config.v"
`include "sign_ext.v"

module new_ls_buffer(
    input wire clk,
    input wire rst,
    input wire rdy,

    // for issuer
    input wire[`RO_BUFFER_ID_TYPE] dest_from_issuer,
    input wire[`OP_TYPE] op_from_issuer,
    input wire[`RO_BUFFER_ID_TYPE] qj_from_issuer,
    input wire[`RO_BUFFER_ID_TYPE] qk_from_issuer,
    input wire[`REG_TYPE] vj_from_issuer,
    input wire[`REG_TYPE] vk_from_issuer,
    input wire[`IMM_TYPE] a_from_issuer,

    // for ls buffer
    input wire[`RO_BUFFER_ID_TYPE] dest_from_lsb_bus,
    input wire[`REG_TYPE] value_from_lsb_bus,

    // for res station
    input wire[`RO_BUFFER_ID_TYPE] dest_from_rss_bus,
    input wire[`REG_TYPE] value_from_rss_bus,

    // for rob bus
    input wire reset_from_rob_bus,
    input wire[`RO_BUFFER_ID_TYPE] store_from_rob_bus, // I need to record which is the last one

    // for lsb bus
    output reg[`RO_BUFFER_ID_TYPE] dest_to_lsb_bus, // TODO: still need to design more dedicate
    output wire[`REG_TYPE] value_to_lsb_bus,

    // mem ctrler
    output reg valid_to_mem_ctrler,
    output reg rw_flag_to_mem_ctrler,
    output reg[`ADDR_TYPE] addr_to_mem_ctrler,
    output reg[`CACHE_LINE_TYPE] cache_line_to_mem_ctrler,
    input wire ready_from_mem_ctrler,
    input wire[`CACHE_LINE_TYPE] cache_line_from_mem_ctrler,

    // mem ctrler
    output reg valid_from_io_to_mem_ctrler,
    output reg rw_flag_from_io_to_mem_ctrler,
    output reg[`ADDR_TYPE] addr_from_io_to_mem_ctrler,
    output reg[`BYTE_TYPE] byte_from_io_to_mem_ctrler,
    input wire ready_from_mem_ctrler_to_io,
    input wire[`BYTE_TYPE] byte_from_mem_ctrler_to_io,

    // for inst_fetcher and others
    output wire is_ls_buffer_full);

  parameter[2:0] IDLE = 0;
  parameter[2:0] READ = 1;
  parameter[2:0] WRITE = 2;
  parameter[2:0] READ_IO = 3;
  parameter[2:0] WRITE_IO = 4;

  // ls buffer
  reg[`OP_TYPE] op[`LOAD_STORE_BUFFER_TYPE];
  reg[`RO_BUFFER_ID_TYPE] qj[`LOAD_STORE_BUFFER_TYPE];
  reg[`RO_BUFFER_ID_TYPE] qk[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] vj[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] vk[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] a[`LOAD_STORE_BUFFER_TYPE];
  reg busy[`LOAD_STORE_BUFFER_TYPE];
  reg[`RO_BUFFER_ID_TYPE] dest[`RESERVATION_STATION_TYPE];

  // cache
  reg[`CACHE_TAG_TYPE] cache_tags[`INST_CACHE_SIZE - 1:0];
  reg[`CACHE_LINE_TYPE][`BYTE_TYPE] cache_lines[`INST_CACHE_SIZE - 1:0];
  reg cache_valid_bits[`INST_CACHE_SIZE - 1:0];
  reg cache_dirty_bits[`INST_CACHE_SIZE - 1:0];

  wire[`CACHE_TAG_TYPE] tag = vj[head][`CACHE_TAG_RANGE];
  wire[`CACHE_INDEX_TYPE] index = vj[head][`CACHE_INDEX_RANGE];
  wire[`CACHE_OFFSET_TYPE] offset = vj[head][`CACHE_OFFSET_RANGE];
  wire hit = cache_valid_bits[index] && cache_tags[index] == tag;

  // sext
  reg is_sign_to_sign_ext;
  reg is_byte_to_sign_ext;
  reg is_half_to_sign_ext;
  reg is_word_to_sign_ext;
  reg[`REG_TYPE] value_to_sign_ext;

  sign_ext sign_ext_0(
             .is_sign(is_sign_to_sign_ext),
             .is_byte(is_byte_to_sign_ext),
             .is_half(is_half_to_sign_ext),
             .is_word(is_word_to_sign_ext),
             .input_data(value_to_sign_ext),
             .extended_data(value_to_lsb_bus));

  // whether it's full, useless currently
  assign is_ls_buffer_full = size >= `LOAD_STORE_BUFFER_SIZE_MINUS_1; // FIXME:

  // state machine and circular queue
  reg[`LS_BUFFER_ID_TYPE] head;
  reg[`LS_BUFFER_ID_TYPE] tail;
  reg[`LS_BUFFER_ID_TYPE] size;

  wire[`LS_BUFFER_ID_TYPE] next_head = head == `LOAD_STORE_BUFFER_SIZE ? 1 : head + 1;
  wire[`LS_BUFFER_ID_TYPE] next_tail = tail == `LOAD_STORE_BUFFER_SIZE ? 1 : tail + 1;

  reg[2:0] state;
  wire is_head_io_signal = vj[head] >= `IO_THRESHOLD;
  wire is_head_executable = size && !qj[head] && !qk[head] && !a[head];
  wire is_head_store = op[head] > `LHU_INST;
  wire is_head_storable = committed_tail != 0;

  wire[`LS_BUFFER_ID_TYPE] committed_tail_offset =
      !committed_tail ? 0 :
      committed_tail >= head ? committed_tail - head :
      `LOAD_STORE_BUFFER_SIZE - head + committed_tail;
  reg[`LS_BUFFER_ID_TYPE] committed_tail;

  // find the one to calculate address
  wire[`LS_BUFFER_ID_TYPE] calc =
      !qj[1] && a[1] && busy[1] ? 1 :
      !qj[2] && a[2] && busy[2] ? 2 :
      !qj[3] && a[3] && busy[3] ? 3 :
      !qj[4] && a[4] && busy[4] ? 4 :
      !qj[5] && a[5] && busy[5] ? 5 :
      !qj[6] && a[6] && busy[6] ? 6 :
      !qj[7] && a[7] && busy[7] ? 7 :
      !qj[8] && a[8] && busy[8] ? 8 :
      !qj[9] && a[9] && busy[9] ? 9 :
      !qj[10] && a[10] && busy[10] ? 10 :
      !qj[11] && a[11] && busy[11] ? 11 :
      !qj[12] && a[12] && busy[12] ? 12 :
      !qj[13] && a[13] && busy[13] ? 13 :
      !qj[14] && a[14] && busy[14] ? 14 :
      !qj[15] && a[15] && busy[15] ? 15 :
      !qj[16] && a[16] && busy[16] ? 16 :
      0;

  always @(posedge clk) begin
    if (rst || reset_from_rob_bus) begin
      if (committed_tail) begin
        tail <= committed_tail == `LOAD_STORE_BUFFER_SIZE ? 1 : committed_tail + 1;
        size <= committed_tail_offset + 1;
        for (integer i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
          if (committed_tail >= head && (i < head || i > committed_tail)) begin
            op[i] <= 0;
            qj[i] <= 0;
            qk[i] <= 0;
            vj[i] <= 0;
            vk[i] <= 0;
            a[i] <= 0;
            busy[i] <= 0;
            dest[i] <= 0;
          end else if (committed_tail < head && (i > committed_tail && i < head)) begin
            op[i] <= 0;
            qj[i] <= 0;
            qk[i] <= 0;
            vj[i] <= 0;
            vk[i] <= 0;
            a[i] <= 0;
            busy[i] <= 0;
            dest[i] <= 0;
          end
        end
      end

      is_sign_to_sign_ext <= 0;
      is_byte_to_sign_ext <= 0;
      is_half_to_sign_ext <= 0;
      is_word_to_sign_ext <= 0;
      dest_to_lsb_bus <= 0;
      value_to_sign_ext <= 0;
      if (rst) begin
        head <= 1;
        tail <= 1;
        size <= 0;
        state <= IDLE;
        committed_tail <= 0;
        for (integer i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
          op[i] <= 0;
          qj[i] <= 0;
          qk[i] <= 0;
          vj[i] <= 0;
          vk[i] <= 0;
          a[i] <= 0;
          busy[i] <= 0;
          dest[i] <= 0;
        end
        for (integer i = 0; i < `INST_CACHE_SIZE; i = i + 1) begin
          cache_valid_bits[i] <= 0;
          cache_tags[i] <= 0;
          cache_lines[i] <= 0;
          cache_dirty_bits[i] <= 0;
        end
      end
    end
  end

  // pick one to calculate address
  always @(posedge clk) begin
    if (!rst && !reset_from_rob_bus) begin
      if (calc) begin
        vj[calc] <= vj[calc] + a[calc];
        a[calc] <= 0;
      end
    end
  end

  // conversion of state
  always @(posedge clk) begin
    if (!rst && !reset_from_rob_bus) begin
      case (state)
        IDLE: begin
          if (is_head_executable) begin
            if (is_head_io_signal) begin // it could only be lb or sb
              if (is_head_store) begin
                if (is_head_storable) begin
                  state <= WRITE_IO;
                  valid_from_io_to_mem_ctrler <= 1;
                  rw_flag_from_io_to_mem_ctrler <= 1;
                  addr_from_io_to_mem_ctrler <= vj[head];
                  byte_from_io_to_mem_ctrler <= vk[head];
                end
              end else begin
                state <= READ_IO;
                valid_from_io_to_mem_ctrler <= 1;
                rw_flag_from_io_to_mem_ctrler <= 0;
                addr_from_io_to_mem_ctrler <= vj[head];
              end
            end else begin
              if (hit) begin
                if (is_head_store) begin
                  if (is_head_storable) begin
                    case(op[head])
                      `SB_INST: begin
                        cache_lines[index][offset] <= vk[head][7:0];
                        cache_dirty_bits[index] <= 1;
                      end

                      `SH_INST: begin
                        cache_lines[index][offset] <= vk[head][7:0];
                        cache_lines[index][offset + 1] <= vk[head][15:8];
                        cache_dirty_bits[index] <= 1;
                      end

                      `SW_INST: begin
                        cache_lines[index][offset] <= vk[head][7:0];
                        cache_lines[index][offset + 1] <= vk[head][15:8];
                        cache_lines[index][offset + 2] <= vk[head][23:16];
                        cache_lines[index][offset + 3] <= vk[head][31:24];
                        cache_dirty_bits[index] <= 1;
                      end
                    endcase
                  end
                end
              end else begin
                valid_to_mem_ctrler <= 1;
                rw_flag_to_mem_ctrler <= 0;
                state <= READ;
                addr_to_mem_ctrler <= vj[head];
              end
            end
          end
        end

        READ: begin
          if (ready_from_mem_ctrler) begin
            cache_lines[index] <= cache_line_from_mem_ctrler;
            cache_tags[index] <= tag;
            cache_valid_bits[index] <= 1;

            if (cache_dirty_bits[index]) begin
              state <= WRITE;
              cache_dirty_bits[index] <= 0;
              rw_flag_to_mem_ctrler <= 1;
              addr_to_mem_ctrler <= index << `CACHE_LINE_WIDTH;
              cache_line_to_mem_ctrler <= cache_lines[index];
            end else begin
              state <= IDLE;
              valid_to_mem_ctrler <= 0;
            end
          end
        end

        WRITE: begin
          if (ready_from_mem_ctrler) begin
            valid_to_mem_ctrler <= 0;
            state <= IDLE;
          end
        end

        READ_IO: begin
          if (ready_from_mem_ctrler_to_io) begin
            state <= IDLE;
            valid_from_io_to_mem_ctrler <= 0;
          end
        end

        WRITE_IO: begin
          if (ready_from_mem_ctrler_to_io) begin
            state <= IDLE;
            valid_from_io_to_mem_ctrler <= 0;
          end
        end
      endcase
    end
  end

  // deal with circular queue
  always @(posedge clk) begin
    if (!rst && !reset_from_rob_bus) begin
      case (state)
        IDLE: begin
          if (hit) begin
            if (!is_head_store || is_head_storable) begin
              busy[head] <= 0;
              head <= next_head;
            end
          end
        end

        READ_IO, WRITE_IO: begin
          if (ready_from_mem_ctrler_to_io) begin
            busy[head] <= 0;
            head <= next_head;
          end
        end
      endcase
    end
  end

  // deal with output
  always @(posedge clk) begin
    if (!rst && !reset_from_rob_bus) begin
      if (state == IDLE && hit && !is_head_store) begin
        case (op[head])
          `LB_INST: value_to_sign_ext <= cache_lines[index][offset];
          `LH_INST: value_to_sign_ext <= {cache_lines[index][offset + 1], cache_lines[index][offset]};
          `LW_INST: value_to_sign_ext <= {cache_lines[index][offset + 3], cache_lines[index][offset + 2], cache_lines[index][offset + 1], cache_lines[index][offset]};
          `LBU_INST: value_to_sign_ext <= cache_lines[index][offset];
          `LHU_INST: value_to_sign_ext <= {cache_lines[index][offset + 1], cache_lines[index][offset]};
        endcase
        is_sign_to_sign_ext <= op[head] < `LBU_INST;
        is_byte_to_sign_ext <= op[head] == `LB_INST || op[head] == `LBU_INST;
        is_half_to_sign_ext <= op[head] == `LH_INST || op[head] == `LHU_INST;
        is_word_to_sign_ext <= op[head] == `LW_INST;
        dest_to_lsb_bus <= dest[head];
      end else if (state == READ_IO && ready_from_mem_ctrler_to_io) begin
        value_to_sign_ext <= byte_from_io_to_mem_ctrler;
        is_sign_to_sign_ext <= 1;
        is_byte_to_sign_ext <= 1;
        is_half_to_sign_ext <= 0;
        is_word_to_sign_ext <= 0;
        dest_to_lsb_bus <= dest[head];
      end else begin
        value_to_sign_ext <= 0;
        is_sign_to_sign_ext <= 0;
        is_byte_to_sign_ext <= 0;
        is_half_to_sign_ext <= 0;
        is_word_to_sign_ext <= 0;
        dest_to_lsb_bus <= 0;
      end
    end
  end

  // update vi & vj
  always @(posedge clk) begin
    if (!rst && !reset_from_rob_bus) begin
      if (dest_from_lsb_bus) begin
        for (integer i = 1; i <= `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
          if (qj[i] == dest_from_lsb_bus) begin
            qj[i] <= 0;
            vj[i] <= value_from_lsb_bus;
          end
          if (qk[i] == dest_from_lsb_bus) begin
            qk[i] <= 0;
            vk[i] <= value_from_lsb_bus;
          end
        end
      end
      if (dest_from_rss_bus) begin
        for (integer i = 1; i <= `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
          if (qj[i] == dest_from_rss_bus) begin
            qj[i] <= 0;
            vj[i] <= value_from_rss_bus;
          end
          if (qk[i] == dest_from_rss_bus) begin
            qk[i] <= 0;
            vk[i] <= value_from_rss_bus;
          end
        end
      end
    end
  end

  // deal with new entry
  always @(posedge clk) begin
    if (!rst && !reset_from_rob_bus)
      if (dest_from_issuer) begin
        op[tail] <= op_from_issuer;

        // never forget to check this!!!
        if (dest_from_rss_bus && qj_from_issuer == dest_from_rss_bus) begin
          qj[tail] <= 0;
          vj[tail] <= value_from_rss_bus;
        end else if (dest_from_lsb_bus && qj_from_issuer == dest_from_lsb_bus) begin
          qj[tail] <= 0;
          vj[tail] <= value_from_lsb_bus;
        end else begin
          qj[tail] <= qj_from_issuer;
          vj[tail] <= vj_from_issuer;
        end

        if (dest_from_rss_bus && qk_from_issuer == dest_from_rss_bus) begin
          qk[tail] <= 0;
          vk[tail] <= value_from_rss_bus;
        end else if (dest_from_lsb_bus && qk_from_issuer == dest_from_lsb_bus) begin
          qk[tail] <= 0;
          vk[tail] <= value_from_lsb_bus;
        end else begin
          qk[tail] <= qk_from_issuer;
          vk[tail] <= vk_from_issuer;
        end

        a[tail] <= a_from_issuer;
        busy[tail] <= 1;
        dest[tail] <= dest_from_issuer;
        tail <= tail == `LOAD_STORE_BUFFER_SIZE ? 1 : tail + 1;
      end
  end

  // deal with size
  always @(posedge clk) begin
    if (!rst && !reset_from_rob_bus) begin
      size <= size
           + (dest_from_issuer != 0)
           - ((state == IDLE && hit && (!is_head_store || is_head_storable)) || ((state == READ_IO || state == WRITE_IO) && ready_from_mem_ctrler_to_io));
    end
  end

  // update committed_store_cnt
  always @(posedge clk) begin
    if (!rst && !reset_from_rob_bus) begin
      if (store_from_rob_bus) begin
        for (integer i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
          if (busy[i] && dest[i] == store_from_rob_bus) begin
            committed_tail <= i;
            dest[i] <= 0;
          end
        end
      end else if ((state == IDLE && hit && (!is_head_store || is_head_storable)) || ((state == READ_IO || state == WRITE_IO) && ready_from_mem_ctrler_to_io)) begin
        if (committed_tail == head) begin
          committed_tail <= 0;
        end
      end
    end
  end

endmodule

`endif