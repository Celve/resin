`ifndef LS_BUFFER_V
`define LS_BUFFER_V

`include "config.v"
`include "sign_ext.v"

module ls_buffer(
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
    input wire store_from_rob_bus,

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

  reg[`OP_TYPE] op[`LOAD_STORE_BUFFER_TYPE];
  reg[`RO_BUFFER_ID_TYPE] qj[`LOAD_STORE_BUFFER_TYPE];
  reg[`RO_BUFFER_ID_TYPE] qk[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] vj[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] vk[`LOAD_STORE_BUFFER_TYPE];
  reg[`REG_TYPE] a[`LOAD_STORE_BUFFER_TYPE];
  reg busy[`LOAD_STORE_BUFFER_TYPE];
  reg[`RO_BUFFER_ID_TYPE] dest[`RESERVATION_STATION_TYPE];

  reg[`CACHE_TAG_TYPE] cache_tags[`INST_CACHE_SIZE - 1:0];
  reg[`CACHE_LINE_TYPE][`BYTE_TYPE] cache_lines[`INST_CACHE_SIZE - 1:0];
  reg cache_valid_bits[`INST_CACHE_SIZE - 1:0];
  reg cache_dirty_bits[`INST_CACHE_SIZE - 1:0];

  reg[`LS_BUFFER_ID_TYPE] head;
  reg[`LS_BUFFER_ID_TYPE] tail;
  reg[`LS_BUFFER_ID_TYPE] size;

  wire[`CACHE_TAG_TYPE] tag = vj[head][`CACHE_TAG_RANGE];
  wire[`CACHE_INDEX_TYPE] index = vj[head][`CACHE_INDEX_RANGE];
  wire[`CACHE_OFFSET_TYPE] offset = vj[head][`CACHE_OFFSET_RANGE];
  wire hit = cache_valid_bits[index] && cache_tags[index] == tag;

  wire is_any_reset = rst || reset_from_rob_bus;

  reg[2:0] state;

  reg is_sign_to_sign_ext;
  reg is_byte_to_sign_ext;
  reg is_half_to_sign_ext;
  reg is_word_to_sign_ext;
  reg[`REG_TYPE] value_to_sign_ext;

  reg[`LS_BUFFER_ID_TYPE] committed_store_cnt;

  wire[`REG_TYPE] addr = vj[head];
  wire[`REG_TYPE] read_value = {cache_lines[index][offset + 3], cache_lines[index][offset + 2], cache_lines[index][offset + 1], cache_lines[index][offset]};
  wire[`REG_TYPE] store_value = vk[head];
  wire[`REG_TYPE] append = a[head];
  wire[`REG_TYPE] desthead = dest[head];
  wire[`REG_TYPE] ophead = op[head];

  sign_ext sign_ext_0(
             .is_sign(is_sign_to_sign_ext),
             .is_byte(is_byte_to_sign_ext),
             .is_half(is_half_to_sign_ext),
             .is_word(is_word_to_sign_ext),
             .input_data(value_to_sign_ext),
             .extended_data(value_to_lsb_bus));

  assign is_ls_buffer_full = size >= `LOAD_STORE_BUFFER_SIZE_MINUS_1; // FIXME:

  wire[`LS_BUFFER_ID_TYPE] calc = // a block way
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
    if (is_any_reset) begin
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

      head <= 1;
      tail <= 1;
      size <= 0;

      state <= IDLE;
      is_sign_to_sign_ext <= 0;
      is_byte_to_sign_ext <= 0;
      is_half_to_sign_ext <= 0;
      is_word_to_sign_ext <= 0;
      dest_to_lsb_bus <= 0;
      value_to_sign_ext <= 0;
      if (rst) begin
        committed_store_cnt <= 0;
        for (integer i = 0; i < `INST_CACHE_SIZE; i = i + 1) begin
          cache_valid_bits[i] <= 0;
          cache_tags[i] <= 0;
          cache_lines[i] <= 0;
          cache_dirty_bits[i] <= 0;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!is_any_reset)
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

  always @(posedge clk) begin
    if (!is_any_reset) begin
      size <= size
           + (dest_from_issuer != 0)
           - ((state == IDLE && size && !qj[head] && !qk[head] && !a[head] && hit && (op[head] < `SB_INST || committed_store_cnt || store_from_rob_bus))
              || (state == READ_IO && ready_from_mem_ctrler_to_io)
              || (state == WRITE_IO && ready_from_mem_ctrler_to_io && (committed_store_cnt || store_from_rob_bus)));
    end
  end

  // calculcate address
  always @(posedge clk) begin
    if (!is_any_reset) begin
      if (calc) begin
        vj[calc] <= vj[calc] + a[calc];
        a[calc] <= 0;
      end
    end
  end

  always @(posedge clk) begin
    if (!is_any_reset) begin
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

  // update committed_store_cnt
  always @(posedge clk) begin
    if (!is_any_reset) begin
      if ((state == IDLE && size && !qj[head] && !qk[head] && !a[head] && hit && op[head] > `LHU_INST) || (state == WRITE_IO && ready_from_mem_ctrler_to_io)) begin
        if (committed_store_cnt) begin
          committed_store_cnt <= store_from_rob_bus ? committed_store_cnt : committed_store_cnt - 1;
        end
      end else if (store_from_rob_bus) begin
        committed_store_cnt <= committed_store_cnt + 1;
      end
    end
  end

  // fetch data
  always @(posedge clk) begin
    if (!is_any_reset) begin
      if (state == IDLE && size && !qj[head] && !qk[head] && !a[head]) begin
        if (vj[head] >= `IO_THRESHOLD) begin
          dest_to_lsb_bus <= 0;
          value_to_sign_ext <= 0;

          if (op[head] < `SB_INST) begin // namely load
            valid_from_io_to_mem_ctrler <= 1;
            addr_from_io_to_mem_ctrler <= vj[head];
            rw_flag_from_io_to_mem_ctrler <= 0;
            state <= READ_IO;
          end else if (committed_store_cnt || store_from_rob_bus) begin
            valid_from_io_to_mem_ctrler <= 1;
            addr_from_io_to_mem_ctrler <= vj[head];
            rw_flag_from_io_to_mem_ctrler <= 1;
            byte_from_io_to_mem_ctrler <= vk[head]; // truncate
            state <= WRITE_IO;
          end
        end else if (hit) begin
          if (op[head] < `SB_INST) begin
            case (op[head])
              `LB_INST: begin
                value_to_sign_ext <= cache_lines[index][offset];
                is_sign_to_sign_ext <= 1;
                is_byte_to_sign_ext <= 1;
                is_half_to_sign_ext <= 0;
                is_word_to_sign_ext <= 0;
              end

              `LH_INST: begin
                value_to_sign_ext <= {cache_lines[index][offset + 1], cache_lines[index][offset]};
                is_sign_to_sign_ext <= 1;
                is_byte_to_sign_ext <= 0;
                is_half_to_sign_ext <= 1;
                is_word_to_sign_ext <= 0;
              end

              `LW_INST: begin
                value_to_sign_ext <= {cache_lines[index][offset + 3], cache_lines[index][offset + 2], cache_lines[index][offset + 1], cache_lines[index][offset]};
                is_sign_to_sign_ext <= 0;
                is_byte_to_sign_ext <= 0;
                is_half_to_sign_ext <= 0;
                is_word_to_sign_ext <= 1;
              end

              `LBU_INST: begin
                value_to_sign_ext <= cache_lines[index][offset];
                is_sign_to_sign_ext <= 0;
                is_byte_to_sign_ext <= 1;
                is_half_to_sign_ext <= 0;
                is_word_to_sign_ext <= 0;
              end

              `LHU_INST: begin
                value_to_sign_ext <= {cache_lines[index][offset + 1], cache_lines[index][offset]};
                is_sign_to_sign_ext <= 0;
                is_byte_to_sign_ext <= 0;
                is_half_to_sign_ext <= 1;
                is_word_to_sign_ext <= 0;
              end
            endcase
            dest_to_lsb_bus <= dest[head];
            head <= head == `LOAD_STORE_BUFFER_SIZE ? 1 : head + 1;
            busy[head] <= 0;
          end else if (committed_store_cnt || store_from_rob_bus) begin
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
            dest_to_lsb_bus <= 0;
            value_to_sign_ext <= 0;
            head <= head == `LOAD_STORE_BUFFER_SIZE ? 1 : head + 1;
            busy[head] <= 0;
          end else begin
            dest_to_lsb_bus <= 0;
            value_to_sign_ext <= 0;
          end
        end else begin
          dest_to_lsb_bus <= 0;
          value_to_sign_ext <= 0;

          state <= READ;
          valid_to_mem_ctrler <= 1;
          rw_flag_to_mem_ctrler <= 0;
          addr_to_mem_ctrler <= vj[head];
        end
      end else if (state == READ) begin
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
            valid_to_mem_ctrler <= 0;
            state <= IDLE;
          end
        end
      end else if (state == WRITE) begin
        if (ready_from_mem_ctrler) begin
          valid_to_mem_ctrler <= 0;
          state <= IDLE;
        end
      end else if (state == READ_IO) begin
        if (ready_from_mem_ctrler_to_io) begin
          valid_from_io_to_mem_ctrler <= 0;
          state <= IDLE;
          value_to_sign_ext <= byte_from_mem_ctrler_to_io;
          is_sign_to_sign_ext <= 1;
          is_byte_to_sign_ext <= 1;
          is_half_to_sign_ext <= 0;
          is_word_to_sign_ext <= 0;
          dest_to_lsb_bus <= dest[head];
          head <= head == `LOAD_STORE_BUFFER_SIZE ? 1 : head + 1;
          busy[head] <= 0;
        end
      end else if (state == WRITE_IO) begin
        if (ready_from_mem_ctrler_to_io) begin
          valid_from_io_to_mem_ctrler <= 0;
          state <= IDLE;
          head <= head == `LOAD_STORE_BUFFER_SIZE ? 1 : head + 1;
          busy[head] <= 0;
        end
      end else begin
        dest_to_lsb_bus <= 0;
        value_to_sign_ext <= 0;
      end
    end
  end

endmodule

`endif
