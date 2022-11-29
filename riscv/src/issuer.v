`ifndef ISSUER_V
`define ISSUER_V

`include "config.v"
`include "decoder.v"

module issuer(
    input wire clk,
    input wire rst,
    input wire rdy,

    // for all
    input wire is_any_full,

    // for inst fetcher
    input wire ready_from_inst_fetcher,
    input wire[`REG_TYPE] pc_from_inst_fetcher,
    input wire[`REG_TYPE] next_pc_from_inst_fetcher,
    input wire[`INST_TYPE] inst_from_inst_fetcher,

    // reg file
    output wire[`REG_ID_TYPE] rs_to_reg_file,
    input wire[`REG_TYPE] vj_from_reg_file,
    input wire[`RO_BUFFER_ID_TYPE] qj_from_reg_file,

    output wire[`REG_ID_TYPE] rt_to_reg_file,
    input wire[`REG_TYPE] vk_from_reg_file,
    input wire[`RO_BUFFER_ID_TYPE] qk_from_reg_file,

    output reg[`REG_ID_TYPE] rd_to_reg_file,
    output reg[`RO_BUFFER_ID_TYPE] dest_to_reg_file, // as long as it's greater than 0, then it takes effects

    // for reorder buffer
    output wire[`RO_BUFFER_ID_TYPE] qj_to_ro_buffer,
    output wire[`RO_BUFFER_ID_TYPE] qk_to_ro_buffer,
    input wire valid_of_vj_from_ro_buffer,
    input wire[`REG_TYPE] vj_from_ro_buffer,
    input wire valid_of_vk_from_ro_buffer,
    input wire[`REG_TYPE] vk_from_ro_buffer,

    // for reorder buffer
    input wire[`RO_BUFFER_ID_TYPE] dest_from_ro_buffer,
    output reg valid_to_ro_buffer,
    output reg[`ISSUER_TO_ROB_SIGNAL_TYPE] signal_to_ro_buffer,
    output reg[`REG_ID_TYPE] rd_to_ro_buffer, // for normal instruction only
    output reg[`REG_TYPE] pc_to_ro_buffer,
    output reg[`REG_TYPE] next_pc_to_ro_buffer, // for branch only

    // for reorder buffer
    input wire reset_from_rob_bus,

    // for res station, only in the next cycle can res station receives these
    // considering obtain them in just one cycle
    output reg[`RO_BUFFER_ID_TYPE] dest_to_rs_station,
    output reg[`OP_TYPE] op_to_rs_station,
    output reg[`RO_BUFFER_ID_TYPE] qj_to_rs_station,
    output reg[`RO_BUFFER_ID_TYPE] qk_to_rs_station,
    output reg[`REG_TYPE] vj_to_rs_station,
    output reg[`REG_TYPE] vk_to_rs_station,
    output reg[`IMM_TYPE] imm_to_rs_station,
    output reg[`REG_TYPE] pc_to_rs_station,

    // for load store buffer
    output reg[`RO_BUFFER_ID_TYPE] dest_to_ls_buffer,
    output reg[`OP_TYPE] op_to_ls_buffer,
    output reg[`RO_BUFFER_ID_TYPE] qj_to_ls_buffer,
    output reg[`RO_BUFFER_ID_TYPE] qk_to_ls_buffer,
    output reg[`REG_TYPE] vj_to_ls_buffer,
    output reg[`REG_TYPE] vk_to_ls_buffer,
    output reg[`IMM_TYPE] a_to_ls_buffer
  );

  wire[`OP_TYPE] op;
  wire[`REG_ID_TYPE] rd;
  wire[`REG_ID_TYPE] rs1;
  wire[`REG_ID_TYPE] rs2;
  wire[`IMM_TYPE] imm;

  wire is_load_or_store;
  wire is_store;
  wire is_branch; // for is_branch, currently, it's b-type instruction + jalr

  decoder decoder_0(
            .inst(inst_from_inst_fetcher),
            .op(op),
            .rd(rd),
            .rs1(rs1),
            .rs2(rs2),
            .imm(imm),
            .is_load_or_store(is_load_or_store),
            .is_store(is_store),
            .is_branch(is_branch));

  assign rs_to_reg_file = rs1;
  assign rt_to_reg_file = rs2;

  assign qj_to_ro_buffer = qj_from_reg_file;
  assign qk_to_ro_buffer = qk_from_reg_file;

  always @(posedge clk) begin
    if (rst || reset_from_rob_bus) begin
      rd_to_reg_file <= 0;
      dest_to_reg_file <= 0;

      valid_to_ro_buffer <= 0;
      signal_to_ro_buffer <= `ISSUER_TO_ROB_SIGNAL_DEFAULT;
      rd_to_ro_buffer <= 0;
      pc_to_ro_buffer <= 0;
      next_pc_to_ro_buffer <= 0;

      dest_to_rs_station <= 0;
      op_to_rs_station <= `NOP_INST;
      qj_to_rs_station <= 0;
      qk_to_rs_station <= 0;
      vj_to_rs_station <= 0;
      vk_to_rs_station <= 0;
      imm_to_rs_station <= 0;
      pc_to_rs_station <= 0;

      dest_to_ls_buffer <= 0;
      op_to_ls_buffer <= `NOP_INST;
      qj_to_ls_buffer <= 0;
      qk_to_ls_buffer <= 0;
      vj_to_ls_buffer <= 0;
      vk_to_ls_buffer <= 0;
      a_to_ls_buffer <= 0;
    end else if (rdy && ready_from_inst_fetcher && !is_any_full) begin
      valid_to_ro_buffer <= 1;
      signal_to_ro_buffer <= is_store ? `ISSUER_TO_ROB_SIGNAL_STORE
                          : is_load_or_store ? `ISSUER_TO_ROB_SIGNAL_LOAD
                          : is_branch ? `ISSUER_TO_ROB_SIGNAL_BRANCH : `ISSUER_TO_ROB_SIGNAL_NORMAL;
      pc_to_ro_buffer <= pc_from_inst_fetcher;
      next_pc_to_ro_buffer <= next_pc_from_inst_fetcher;

      if (is_load_or_store) begin
        // for ro buffer
        rd_to_ro_buffer <= rd; // TODO: check whether rt = rs2

        // for reg file
        rd_to_reg_file <= rd; // TODO: check whether rt = rs2
        dest_to_reg_file <= dest_from_ro_buffer; // TODO: check whether rt = rs2

        // for ls buffer
        dest_to_ls_buffer <= dest_from_ro_buffer;
        dest_to_rs_station <= 0;
        op_to_ls_buffer <= op;
        a_to_ls_buffer <= imm;

        // it might be busy, therefore check ro buffer
        if (qj_from_reg_file && valid_of_vj_from_ro_buffer) begin
          qj_to_ls_buffer <= 0;
          vj_to_ls_buffer <= vj_from_ro_buffer;
        end else begin
          qj_to_ls_buffer <= qj_from_reg_file;
          vj_to_ls_buffer <= vj_from_reg_file;
        end

        if (qk_from_reg_file && valid_of_vk_from_ro_buffer) begin
          qk_to_ls_buffer <= 0;
          vk_to_ls_buffer <= vk_from_ro_buffer;
        end else begin
          qk_to_ls_buffer <= qk_from_reg_file;
          vk_to_ls_buffer <= vk_from_reg_file;
        end
      end else begin
        // for ro buffer
        rd_to_ro_buffer <= rd;

        // for reg file
        rd_to_reg_file <= rd; // TODO: check whether rt = rs2
        dest_to_reg_file <= dest_from_ro_buffer; // TODO: check whether rt = rs2

        // for res station
        dest_to_rs_station <= dest_from_ro_buffer;
        dest_to_ls_buffer <= 0;
        op_to_rs_station <= op;
        imm_to_rs_station <= imm;
        pc_to_rs_station <= pc_from_inst_fetcher;

        // it might be busy, therefore check ro buffer
        if (qj_from_reg_file && valid_of_vj_from_ro_buffer) begin
          qj_to_rs_station <= 0;
          vj_to_rs_station <= vj_from_ro_buffer;
        end else begin
          qj_to_rs_station <= qj_from_reg_file;
          vj_to_rs_station <= vj_from_reg_file;
        end

        if (qk_from_reg_file && valid_of_vk_from_ro_buffer) begin
          qk_to_rs_station <= 0;
          vk_to_rs_station <= vk_from_ro_buffer;
        end else begin
          qk_to_rs_station <= qk_from_reg_file;
          vk_to_rs_station <= vk_from_reg_file;
        end
      end
    end else if (rdy) begin
      dest_to_rs_station <= 0;
      dest_to_ls_buffer <= 0;
      valid_to_ro_buffer <= 0;
      rd_to_reg_file <= 0;
    end
  end

endmodule

`endif
