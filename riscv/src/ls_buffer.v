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

    // for inst_fetcher and others
    output wire is_ls_buffer_full);

  parameter[2:0] IDLE = 0;
  parameter[2:0] READ = 1;
  parameter[2:0] WRITE = 1;

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

  reg[`LS_BUFFER_ID_TYPE] last_exec;

  wire[`CACHE_TAG_TYPE] tag = vj[exec][`CACHE_TAG_RANGE];
  wire[`CACHE_INDEX_TYPE] index = vj[exec][`CACHE_INDEX_RANGE];
  wire[`CACHE_OFFSET_TYPE] offset = vj[exec][`CACHE_OFFSET_RANGE];
  wire hit = cache_valid_bits[index] && cache_tags[index] == tag;

  wire is_any_reset = rst || reset_from_rob_bus;

  reg[2:0] state;

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

  assign is_ls_buffer_full =
         busy[1] & busy[2] & busy[3] & busy[4] &
         busy[5] & busy[6] & busy[7] & busy[8] &
         busy[9] & busy[10] & busy[11] & busy[12] &
         busy[13] & busy[14] & busy[15] & busy[16];

  wire[`LS_BUFFER_ID_TYPE] free =
      !busy[1] ? 1 :
      !busy[2] ? 2 :
      !busy[3] ? 3 :
      !busy[4] ? 4 :
      !busy[5] ? 5 :
      !busy[6] ? 6 :
      !busy[7] ? 7 :
      !busy[8] ? 8 :
      !busy[9] ? 9 :
      !busy[10] ? 10 :
      !busy[11] ? 11 :
      !busy[12] ? 12 :
      !busy[13] ? 13 :
      !busy[14] ? 14 :
      !busy[15] ? 15 :
      !busy[16] ? 16 :
      0;

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

  wire[`RES_STATION_ID_TYPE] exec =
      last_exec ? last_exec :
      !qj[1] && !qk[1] && !a[1] && busy[1] ? 1 :
      !qj[2] && !qk[2] && !a[2] && busy[2] ? 2 :
      !qj[3] && !qk[3] && !a[3] && busy[3] ? 3 :
      !qj[4] && !qk[4] && !a[4] && busy[4] ? 4 :
      !qj[5] && !qk[5] && !a[5] && busy[5] ? 5 :
      !qj[6] && !qk[6] && !a[6] && busy[6] ? 6 :
      !qj[7] && !qk[7] && !a[7] && busy[7] ? 7 :
      !qj[8] && !qk[8] && !a[8] && busy[8] ? 8 :
      !qj[9] && !qk[9] && !a[9] && busy[9] ? 9 :
      !qj[10] && !qk[10] && !a[10] && busy[10] ? 10 :
      !qj[11] && !qk[11] && !a[11] && busy[11] ? 11 :
      !qj[12] && !qk[12] && !a[12] && busy[12] ? 12 :
      !qj[13] && !qk[13] && !a[13] && busy[13] ? 13 :
      !qj[14] && !qk[14] && !a[14] && busy[14] ? 14 :
      !qj[15] && !qk[15] && !a[15] && busy[15] ? 15 :
      !qj[16] && !qk[16] && !a[16] && busy[16] ? 16 :
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
      last_exec <= 0;
      state <= IDLE;
      is_sign_to_sign_ext <= 0;
      is_byte_to_sign_ext <= 0;
      is_half_to_sign_ext <= 0;
      is_word_to_sign_ext <= 0;
      value_to_sign_ext <= 0;
      if (rst) begin
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
        op[free] <= op_from_issuer;
        qj[free] <= qj_from_issuer;
        qk[free] <= qk_from_issuer;
        vj[free] <= vj_from_issuer;
        vk[free] <= vk_from_issuer;
        a[free] <= a_from_issuer;
        busy[free] <= 1;
        dest[free] <= dest_from_issuer;
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
        for (integer i = 0; i < `LOAD_STORE_BUFFER_SIZE; i = i + 1) begin
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
        for (integer i = 0; i < `LOAD_STORE_BUFFER_SIZE; i = i + 1) begin
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

  // fetch data
  always @(posedge clk) begin
    if (!is_any_reset) begin
      if (state == IDLE && exec) begin
        if (hit) begin
          case (op[exec])
            `LB_INST: begin
              dest_to_lsb_bus <= dest[last_exec];
              value_to_sign_ext <= cache_lines[index][offset];
              is_sign_to_sign_ext <= 1;
              is_byte_to_sign_ext <= 1;
              is_half_to_sign_ext <= 0;
              is_word_to_sign_ext <= 0;
            end

            `LH_INST: begin
              dest_to_lsb_bus <= dest[last_exec];
              value_to_sign_ext <= {cache_lines[index][offset + 1], cache_lines[index][offset]};
              is_sign_to_sign_ext <= 1;
              is_byte_to_sign_ext <= 0;
              is_half_to_sign_ext <= 1;
              is_word_to_sign_ext <= 0;
            end

            `LW_INST: begin
              dest_to_lsb_bus <= dest[last_exec];
              value_to_sign_ext <= {cache_lines[index][offset + 3], cache_lines[index][offset + 2], cache_lines[index][offset + 1], cache_lines[index][offset]};
              is_sign_to_sign_ext <= 0;
              is_byte_to_sign_ext <= 0;
              is_half_to_sign_ext <= 0;
              is_word_to_sign_ext <= 1;
            end

            `LBU_INST: begin
              dest_to_lsb_bus <= dest[last_exec];
              value_to_sign_ext <= cache_lines[index][offset];
              is_sign_to_sign_ext <= 0;
              is_byte_to_sign_ext <= 1;
              is_half_to_sign_ext <= 0;
              is_word_to_sign_ext <= 0;
            end

            `LHU_INST: begin
              dest_to_lsb_bus <= dest[last_exec];
              value_to_sign_ext <= cache_lines[index][offset];
              is_sign_to_sign_ext <= 0;
              is_byte_to_sign_ext <= 0;
              is_half_to_sign_ext <= 1;
              is_word_to_sign_ext <= 0;
            end

            `SB_INST: begin
              cache_lines[index][offset] <= vk[exec][7:0];
              cache_dirty_bits[index] <= 1;
            end

            `SH_INST: begin
              cache_lines[index][offset] <= vk[exec][7:0];
              cache_lines[index][offset + 1] <= vk[exec][15:8];
              cache_dirty_bits[index] <= 1;
            end

            `SW_INST: begin
              cache_lines[index][offset] <= vk[exec][7:0];
              cache_lines[index][offset + 1] <= vk[exec][15:8];
              cache_lines[index][offset + 2] <= vk[exec][23:16];
              cache_lines[index][offset + 3] <= vk[exec][31:24];
              cache_dirty_bits[index] <= 1;
            end
          endcase
          last_exec <= 0;
          busy[exec] <= 0;
        end else begin
          dest_to_lsb_bus <= 0;

          state <= READ;
          last_exec <= exec;
          valid_to_mem_ctrler <= 1;
          rw_flag_to_mem_ctrler <= 0;
          addr_to_mem_ctrler <= vj[exec];
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
        valid_to_mem_ctrler <= 0;
        state <= IDLE;
      end
    end
  end

endmodule

`endif
