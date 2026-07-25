`timescale 1ns / 1ps
`include "ntt_defs.vh"

module poly_basemul (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [`NTT_DATA_WIDTH-1:0] din_a,
    input wire [`NTT_DATA_WIDTH-1:0] din_b,
    input wire [`NTT_DATA_WIDTH-1:0] gamma_i,
    output reg [7:0] addr_rd,
    output reg [7:0] addr_wr,
    output wire [6:0] gamma_addr,
    output reg [`NTT_DATA_WIDTH-1:0] dout,
    output reg we_out,
    output reg busy,
    output reg done
);

    `include "ntt_funcs.vh"

    localparam ST_IDLE = 2'd0;
    localparam ST_RUN = 2'd1;
    localparam ST_DRAIN = 2'd2;

    localparam PH_A0B0 = 3'd0;
    localparam PH_A1B1 = 3'd1;
    localparam PH_A0B1 = 3'd2;
    localparam PH_A1B0 = 3'd3;
    localparam PH_NEXT_A0B0 = 3'd4;
    localparam PH_GAMMA = 3'd5;

    localparam MUL_A0B0 = 3'd0;
    localparam MUL_A1B1 = 3'd1;
    localparam MUL_A0B1 = 3'd2;
    localparam MUL_A1B0 = 3'd3;
    localparam MUL_GAMMA = 3'd4;

    reg [1:0] state;
    reg [2:0] phase;
    reg [6:0] pair_idx;

    reg [`NTT_DATA_WIDTH-1:0] a0_r;
    reg [`NTT_DATA_WIDTH-1:0] a1_r;
    reg [`NTT_DATA_WIDTH-1:0] b0_r;
    reg [`NTT_DATA_WIDTH-1:0] b1_r;

    reg [`NTT_DATA_WIDTH-1:0] res_a0b0 [0:1];
    reg [`NTT_DATA_WIDTH-1:0] res_a0b1 [0:1];

    reg [3:0] tag_valid;
    reg [2:0] tag_op [0:3];
    reg [6:0] tag_pair [0:3];

    reg issue_valid;
    reg [2:0] issue_op;
    reg [6:0] issue_pair;
    reg [`NTT_DATA_WIDTH-1:0] mul_a;
    reg [`NTT_DATA_WIDTH-1:0] mul_b;
    wire [`NTT_DATA_WIDTH-1:0] mul_r;

    reg final_write_pending;

    wire [6:0] next_pair_idx = pair_idx + 7'd1;
    wire [`NTT_QWIDTH-1:0] gamma_neg = `NTT_Q - {1'b0, gamma_i};
    wire [`NTT_DATA_WIDTH-1:0] gamma_value =
        pair_idx[0] ? gamma_neg[`NTT_DATA_WIDTH-1:0] : gamma_i;

    assign gamma_addr = 7'd64 + {1'b0, pair_idx[6:1]};

    ntt_mod_mul_12b u_mul (
        .clk(clk),
        .a_i(mul_a),
        .b_i(mul_b),
        .r_o(mul_r)
    );

    always @(*) begin
        addr_rd = {pair_idx, 1'b0};
        issue_valid = 1'b0;
        issue_op = MUL_A0B0;
        issue_pair = pair_idx;
        mul_a = {`NTT_DATA_WIDTH{1'b0}};
        mul_b = {`NTT_DATA_WIDTH{1'b0}};

        if (state == ST_RUN) begin
            case (phase)
                PH_A0B0: begin
                    mul_a = din_a;
                    mul_b = din_b;
                    issue_valid = 1'b1;
                    issue_op = MUL_A0B0;
                end
                PH_A1B1: begin
                    addr_rd = {pair_idx, 1'b1};
                    mul_a = din_a;
                    mul_b = din_b;
                    issue_valid = 1'b1;
                    issue_op = MUL_A1B1;
                end
                PH_A0B1: begin
                    mul_a = a0_r;
                    mul_b = b1_r;
                    issue_valid = 1'b1;
                    issue_op = MUL_A0B1;
                end
                PH_A1B0: begin
                    mul_a = a1_r;
                    mul_b = b0_r;
                    issue_valid = 1'b1;
                    issue_op = MUL_A1B0;
                end
                PH_NEXT_A0B0: begin
                    addr_rd = {next_pair_idx, 1'b0};
                    if (pair_idx != 7'd127) begin
                        mul_a = din_a;
                        mul_b = din_b;
                        issue_valid = 1'b1;
                        issue_op = MUL_A0B0;
                        issue_pair = next_pair_idx;
                    end
                end
                PH_GAMMA: begin
                    mul_a = mul_r;
                    mul_b = gamma_value;
                    issue_valid = 1'b1;
                    issue_op = MUL_GAMMA;
                end
                default: begin
                    issue_valid = 1'b0;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            phase <= PH_A0B0;
            pair_idx <= 7'd0;
            a0_r <= {`NTT_DATA_WIDTH{1'b0}};
            a1_r <= {`NTT_DATA_WIDTH{1'b0}};
            b0_r <= {`NTT_DATA_WIDTH{1'b0}};
            b1_r <= {`NTT_DATA_WIDTH{1'b0}};
            res_a0b0[0] <= {`NTT_DATA_WIDTH{1'b0}};
            res_a0b0[1] <= {`NTT_DATA_WIDTH{1'b0}};
            res_a0b1[0] <= {`NTT_DATA_WIDTH{1'b0}};
            res_a0b1[1] <= {`NTT_DATA_WIDTH{1'b0}};
            tag_valid <= 4'd0;
            tag_op[0] <= MUL_A0B0;
            tag_op[1] <= MUL_A0B0;
            tag_op[2] <= MUL_A0B0;
            tag_op[3] <= MUL_A0B0;
            tag_pair[0] <= 7'd0;
            tag_pair[1] <= 7'd0;
            tag_pair[2] <= 7'd0;
            tag_pair[3] <= 7'd0;
            addr_wr <= 8'd0;
            dout <= {`NTT_DATA_WIDTH{1'b0}};
            we_out <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            final_write_pending <= 1'b0;
        end else begin
            done <= 1'b0;
            we_out <= 1'b0;

            tag_valid <= {tag_valid[2:0], issue_valid};
            tag_op[3] <= tag_op[2];
            tag_op[2] <= tag_op[1];
            tag_op[1] <= tag_op[0];
            tag_op[0] <= issue_op;
            tag_pair[3] <= tag_pair[2];
            tag_pair[2] <= tag_pair[1];
            tag_pair[1] <= tag_pair[0];
            tag_pair[0] <= issue_pair;

            if (tag_valid[3]) begin
                case (tag_op[3])
                    MUL_A0B0: begin
                        res_a0b0[tag_pair[3][0]] <= mul_r;
                    end
                    MUL_A0B1: begin
                        res_a0b1[tag_pair[3][0]] <= mul_r;
                    end
                    MUL_A1B0: begin
                        addr_wr <= {tag_pair[3], 1'b1};
                        dout <= ntt_mod_add(res_a0b1[tag_pair[3][0]], mul_r);
                        we_out <= 1'b1;
                    end
                    MUL_GAMMA: begin
                        addr_wr <= {tag_pair[3], 1'b0};
                        dout <= ntt_mod_add(res_a0b0[tag_pair[3][0]], mul_r);
                        we_out <= 1'b1;
                        if (tag_pair[3] == 7'd127) begin
                            final_write_pending <= 1'b1;
                        end
                    end
                    default: begin
                    end
                endcase
            end

            if (final_write_pending) begin
                final_write_pending <= 1'b0;
                state <= ST_IDLE;
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                case (state)
                    ST_IDLE: begin
                        tag_valid <= 4'd0;
                        pair_idx <= 7'd0;
                        phase <= PH_A0B0;
                        busy <= 1'b0;
                        if (start) begin
                            state <= ST_RUN;
                            busy <= 1'b1;
                        end
                    end
                    ST_RUN: begin
                        case (phase)
                            PH_A0B0: begin
                                a0_r <= din_a;
                                b0_r <= din_b;
                                phase <= PH_A1B1;
                            end
                            PH_A1B1: begin
                                a1_r <= din_a;
                                b1_r <= din_b;
                                phase <= PH_A0B1;
                            end
                            PH_A0B1: begin
                                phase <= PH_A1B0;
                            end
                            PH_A1B0: begin
                                phase <= PH_NEXT_A0B0;
                            end
                            PH_NEXT_A0B0: begin
                                if (pair_idx != 7'd127) begin
                                    a0_r <= din_a;
                                    b0_r <= din_b;
                                end
                                phase <= PH_GAMMA;
                            end
                            PH_GAMMA: begin
                                if (pair_idx == 7'd127) begin
                                    state <= ST_DRAIN;
                                end else begin
                                    pair_idx <= pair_idx + 7'd1;
                                    phase <= PH_A1B1;
                                end
                            end
                            default: phase <= PH_A0B0;
                        endcase
                    end
                    ST_DRAIN: begin
                        busy <= 1'b1;
                    end
                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
