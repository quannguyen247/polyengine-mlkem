`timescale 1ns / 1ps
`include "ntt_defs.vh"

module poly_ram_multi #(
    parameter N_POLY = 8,
    parameter POLY_SIZE = 256,
    parameter ADDR_WIDTH = 8,
    parameter POLY_SEL_WIDTH = 3
)(
    input wire clk,
    input wire we,
    input wire [POLY_SEL_WIDTH-1:0] poly_sel_wr,
    input wire [ADDR_WIDTH-1:0] addr_wr,
    input wire [`NTT_DATA_WIDTH-1:0] din,
    input wire [POLY_SEL_WIDTH-1:0] poly_sel_a,
    input wire [ADDR_WIDTH-1:0] addr_a,
    output wire [`NTT_DATA_WIDTH-1:0] dout_a,
    input wire [POLY_SEL_WIDTH-1:0] poly_sel_b,
    input wire [ADDR_WIDTH-1:0] addr_b,
    output wire [`NTT_DATA_WIDTH-1:0] dout_b
);

    localparam FULL_ADDR_WIDTH = POLY_SEL_WIDTH + ADDR_WIDTH;

    reg [`NTT_DATA_WIDTH-1:0] mem [0:(N_POLY*POLY_SIZE)-1];

    wire [FULL_ADDR_WIDTH-1:0] full_addr_wr = {poly_sel_wr, addr_wr};
    wire [FULL_ADDR_WIDTH-1:0] full_addr_a = {poly_sel_a, addr_a};
    wire [FULL_ADDR_WIDTH-1:0] full_addr_b = {poly_sel_b, addr_b};

    always @(posedge clk) begin
        if (we) begin
            mem[full_addr_wr] <= din;
        end
    end

    assign dout_a = mem[full_addr_a];
    assign dout_b = mem[full_addr_b];

endmodule