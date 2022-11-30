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
    input wire[`RO_BUFFER_ID_TYPE] dest_from_rob_bus, // I need to record which is the last one
    input wire ls_select_from_rob_bus,

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
  reg[`RO_BUFFER_ID_TYPE] dest[`LOAD_STORE_BUFFER_TYPE];

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

  // state machine and circular queue
  reg[`LS_BUFFER_ID_TYPE] head;
  reg[`LS_BUFFER_ID_TYPE] tail;
  reg[`LS_BUFFER_ID_TYPE] size;

  // cache
  reg[`CACHE_TAG_TYPE] cache_tags[`CACHE_SIZE - 1:0];
  reg[`CACHE_LINE_TYPE] cache_lines[`CACHE_SIZE - 1:0];
  reg cache_valid_bits[`CACHE_SIZE - 1:0];
  reg cache_dirty_bits[`CACHE_SIZE - 1:0];

  wire[`CACHE_TAG_TYPE] tag = vj[head][`CACHE_TAG_RANGE];
  wire[`CACHE_INDEX_TYPE] index = vj[head][`CACHE_INDEX_RANGE];
  wire[`CACHE_OFFSET_TYPE] offset = vj[head][`CACHE_OFFSET_RANGE] << 3;
  wire hit = cache_valid_bits[index] && cache_tags[index] == tag;

  // whether it's full, useless currently
  assign is_ls_buffer_full = size >= `LOAD_STORE_BUFFER_SIZE_MINUS_1; // FIXME:

  wire[`LS_BUFFER_ID_TYPE] next_head = head == `LOAD_STORE_BUFFER_SIZE ? 1 : head + 1;
  wire[`LS_BUFFER_ID_TYPE] next_tail = tail == `LOAD_STORE_BUFFER_SIZE ? 1 : tail + 1;

  reg[2:0] state;
  wire is_head_io_signal = vj[head] >= `IO_THRESHOLD;
  wire is_head_executable = size && !qj[head] && !qk[head] && !a[head];
  wire is_head_store = op[head] > `LHU_INST;

  reg[`LS_BUFFER_ID_TYPE] committed_tail;
  wire is_head_committed = committed_tail != 0;

  wire[`LS_BUFFER_ID_TYPE] committed_tail_offset =
      !committed_tail ? 0 :
      committed_tail >= head ? committed_tail - head :
      `LOAD_STORE_BUFFER_SIZE - head + committed_tail;

  // io buffer
  reg ready_from_io_buffer;
  reg[`BYTE_TYPE] byte_from_io_buffer;

  // cache buffer
  reg ready_from_cache_buffer;
  reg[`CACHE_LINE_TYPE] cache_line_from_cache_buffer;

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

  // integer declaration
  integer i;

  always @(posedge clk) begin
    if (rst) begin
      dest_to_lsb_bus <= 0;

      valid_to_mem_ctrler <= 0;

      valid_from_io_to_mem_ctrler <= 0;

      ready_from_cache_buffer <= 0;
      ready_from_io_buffer <= 0;
      head <= 1;
      tail <= 1;
      size <= 0;
      state <= IDLE;
      committed_tail <= 0;

      for (i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
        op[i] <= 0;
        qj[i] <= 0;
        qk[i] <= 0;
        vj[i] <= 0;
        vk[i] <= 0;
        a[i] <= 0;
        busy[i] <= 0;
        dest[i] <= 0;
      end

      for (i = 0; i < `CACHE_SIZE; i = i + 1) begin
        cache_valid_bits[i] <= 0;
        cache_tags[i] <= 0;
        cache_dirty_bits[i] <= 0;
      end

      is_sign_to_sign_ext <= 0;
      is_byte_to_sign_ext <= 0;
      is_half_to_sign_ext <= 0;
      is_word_to_sign_ext <= 0;
      value_to_sign_ext <= 0;
    end else if (reset_from_rob_bus) begin
      if (ready_from_mem_ctrler_to_io) begin
        ready_from_io_buffer <= 1;
        byte_from_io_buffer <= byte_from_mem_ctrler_to_io;
        valid_from_io_to_mem_ctrler <= 0;
      end
      if (ready_from_mem_ctrler) begin
        ready_from_cache_buffer <= 1;
        cache_line_from_cache_buffer <= cache_line_from_mem_ctrler;
        valid_to_mem_ctrler <= 0;
      end
      if (committed_tail) begin
        tail <= committed_tail == `LOAD_STORE_BUFFER_SIZE ? 1 : committed_tail + 1;
        size <= committed_tail_offset + 1;
        for (i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
          if ((committed_tail >= head && (i < head || i > committed_tail))
              || (committed_tail < head && (i > committed_tail && i < head))) begin
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
      end else begin
        head <= 1;
        tail <= 1;
        size <= 0;
        for (i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
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

      is_sign_to_sign_ext <= 0;
      is_byte_to_sign_ext <= 0;
      is_half_to_sign_ext <= 0;
      is_word_to_sign_ext <= 0;
      dest_to_lsb_bus <= 0;
      value_to_sign_ext <= 0;
    end else if (rdy) begin
      // pick one to calculate address
      if (calc) begin
        vj[calc] <= vj[calc] + a[calc];
        a[calc] <= 0;
      end

      // conversion of state
      case (state)
        IDLE: begin
          if (is_head_executable) begin
            if (is_head_io_signal) begin // it could only be lb or sb
              if (is_head_store) begin
                if (is_head_committed) begin
                  state <= WRITE_IO;
                  valid_from_io_to_mem_ctrler <= 1;
                  rw_flag_from_io_to_mem_ctrler <= 1;
                  addr_from_io_to_mem_ctrler <= vj[head];
                  byte_from_io_to_mem_ctrler <= vk[head];
                end
              end else begin
                if (is_head_committed) begin
                  state <= READ_IO;
                  valid_from_io_to_mem_ctrler <= 1;
                  rw_flag_from_io_to_mem_ctrler <= 0;
                  addr_from_io_to_mem_ctrler <= vj[head];
                end
              end
            end else begin
              if (hit) begin
                if (is_head_store) begin
                  if (is_head_committed) begin
                    case(op[head])
                      `SB_INST: begin
                        cache_lines[index][offset +: 8] <= vk[head][7:0];
                        cache_dirty_bits[index] <= 1;
                      end

                      `SH_INST: begin
                        cache_lines[index][offset +: 16] <= vk[head][15:0];
                        cache_dirty_bits[index] <= 1;
                      end

                      `SW_INST: begin
                        cache_lines[index][offset +: 32] <= vk[head][31:0];
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
          if (ready_from_mem_ctrler || ready_from_cache_buffer) begin
            if (addr_to_mem_ctrler != vj[head]) begin
              state <= IDLE;
              if (ready_from_mem_ctrler) begin
                valid_to_mem_ctrler <= 0;
              end else begin
                ready_from_cache_buffer <= 0;
              end
            end else begin
              cache_lines[index] <= ready_from_mem_ctrler ? cache_line_from_mem_ctrler : cache_line_from_cache_buffer;
              cache_tags[index] <= tag;
              cache_valid_bits[index] <= 1;

              if (cache_dirty_bits[index]) begin
                state <= WRITE;
                cache_dirty_bits[index] <= 0;
                rw_flag_to_mem_ctrler <= 1;
                addr_to_mem_ctrler <= (cache_tags[index] << `CACHE_INDEX_AND_LINE_WIDTH) | (index << `CACHE_LINE_WIDTH);
                cache_line_to_mem_ctrler <= cache_lines[index];
                if (ready_from_cache_buffer) begin
                  valid_to_mem_ctrler <= 1;
                  ready_from_cache_buffer <= 0;
                end
              end else begin
                state <= IDLE;
                if (ready_from_mem_ctrler) begin
                  valid_to_mem_ctrler <= 0;
                end else begin
                  ready_from_cache_buffer <= 0;
                end
              end
            end
          end
        end

        WRITE: begin
          if (ready_from_mem_ctrler) begin // FIXME: fix like the previous one
            state <= IDLE;
            valid_to_mem_ctrler <= 0;
          end else if (ready_from_cache_buffer) begin
            state <= IDLE;
            ready_from_cache_buffer <= 0;
          end
        end

        READ_IO: begin
          if (ready_from_mem_ctrler_to_io) begin
            state <= IDLE;
            valid_from_io_to_mem_ctrler <= 0;
          end else if (ready_from_io_buffer) begin
            state <= IDLE;
            ready_from_io_buffer <= 0;
          end
        end

        WRITE_IO: begin
          if (ready_from_mem_ctrler_to_io) begin
            state <= IDLE;
            valid_from_io_to_mem_ctrler <= 0;
          end else if (ready_from_io_buffer) begin
            state <= IDLE;
            ready_from_io_buffer <= 0;
          end
        end
      endcase

      // deal with circular queue
      case (state)
        IDLE: begin
          if (is_head_executable && !is_head_io_signal && hit) begin
            if (!is_head_store || is_head_committed) begin
              busy[head] <= 0;
              dest[head] <= 0;
              head <= next_head;
            end
          end
        end

        READ_IO, WRITE_IO: begin
          if (ready_from_mem_ctrler_to_io || ready_from_io_buffer) begin
            busy[head] <= 0;
            dest[head] <= 0;
            head <= next_head;
          end
        end
      endcase

      // deal with output
      if (state == IDLE && is_head_executable && !is_head_io_signal && hit && !is_head_store) begin
        case (op[head])
          `LB_INST: value_to_sign_ext <= cache_lines[index][offset +: 8];
          `LH_INST: value_to_sign_ext <= cache_lines[index][offset +: 16];
          `LW_INST: value_to_sign_ext <= cache_lines[index][offset +: 32];
          `LBU_INST: value_to_sign_ext <= cache_lines[index][offset +: 8];
          `LHU_INST: value_to_sign_ext <= cache_lines[index][offset +: 16];
        endcase
        is_sign_to_sign_ext <= op[head] < `LBU_INST;
        is_byte_to_sign_ext <= op[head] == `LB_INST || op[head] == `LBU_INST;
        is_half_to_sign_ext <= op[head] == `LH_INST || op[head] == `LHU_INST;
        is_word_to_sign_ext <= op[head] == `LW_INST;
        dest_to_lsb_bus <= dest[head];
      end else if (state == READ_IO && (ready_from_mem_ctrler_to_io || ready_from_io_buffer)) begin
        value_to_sign_ext <= ready_from_mem_ctrler_to_io ? byte_from_mem_ctrler_to_io : byte_from_io_buffer;
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

      // update vi & vj
      if (dest_from_lsb_bus) begin
        for (i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
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
        for (i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
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

      // deal with new entry
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

      // deal with size
      size <= size
           + (dest_from_issuer != 0)
           - ((state == IDLE && is_head_executable && !is_head_io_signal && hit && (!is_head_store || is_head_committed)) || ((state == READ_IO || state == WRITE_IO) && (ready_from_mem_ctrler_to_io || ready_from_io_buffer)));

      // update committed_store_cnt
      if (dest_from_rob_bus && ls_select_from_rob_bus) begin
        for (i = 1; i < `LOAD_STORE_BUFFER_SIZE_PLUS_1; i = i + 1) begin
          if (busy[i] && dest[i] == dest_from_rob_bus) begin
            committed_tail <= i;
            dest[i] <= 0; // store doesn't need to be committed
          end
        end
      end else if (dest_from_rob_bus && !ls_select_from_rob_bus && !committed_tail && is_head_io_signal && dest[head] == dest_from_rob_bus) begin
        committed_tail <= head;
      end else if ((state == IDLE && is_head_executable && !is_head_io_signal && hit && (!is_head_store || is_head_committed)) || ((state == READ_IO || state == WRITE_IO) && (ready_from_mem_ctrler_to_io || ready_from_io_buffer))) begin
        if (committed_tail == head) begin
          committed_tail <= 0;
        end
      end
    end
  end

endmodule

`endif
