`timescale 1ns / 1ps
`include "ntt_defs.vh"

module poly_arith (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire mode,
    input wire [`NTT_DATA_WIDTH-1:0] din_a,
    input wire [`NTT_DATA_WIDTH-1:0] din_b,
    output wire [7:0] addr_out,
    output wire [`NTT_DATA_WIDTH-1:0] dout,
    output wire we_out,
    output reg busy,
    output reg done
);

    `include "ntt_funcs.vh"

    reg mode_r;
    reg [7:0] cnt;

    assign addr_out = cnt;
    assign dout = mode_r ? ntt_mod_sub(din_a, din_b) : ntt_mod_add(din_a, din_b);
    assign we_out = busy;

    always @(posedge clk) begin
        if (!rst_n) begin
            mode_r <= 1'b0;
            cnt <= 8'd0;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                if (start) begin
                    mode_r <= mode;
                    cnt <= 8'd0;
                    busy <= 1'b1;
                end
            end else if (cnt == 8'd255) begin
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                cnt <= cnt + 8'd1;
            end
        end
    end

endmodule