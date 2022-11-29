`ifndef SIGN_EXT_V
`define SIGN_EXT_V

`include "config.v"

module sign_ext(
    input wire is_sign,
    input wire is_byte,
    input wire is_half,
    input wire is_word,
    input wire[`REG_TYPE] input_data,
    output reg[`REG_TYPE] extended_data);

  always @(*) begin
    if (is_sign || is_word) begin
      extended_data = input_data;
    end else if (is_byte) begin
      extended_data = {{24{input_data[7]}}, input_data[7:0]};
    end else if (is_half) begin // is_half
      extended_data = {{16{input_data[15]}}, input_data[15:0]};
    end else begin
      extended_data = 0;
    end
  end

endmodule

`endif
