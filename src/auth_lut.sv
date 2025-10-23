`timescale 1ns/1ps

// UID LUT with add/check, duplicate detection, and full detection
module auth_lut #(
    parameter UID_MAX = 4,       // number of UIDs allowed
    parameter UID_LEN = 4        // each UID length (bytes)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] cmd,
    input  wire       valid,
    output reg        uid_allowed,
    output reg        uid_added_ok,
    output reg        uid_duplicate,
    output reg        uid_full
);

    // Small memory for UIDs
    reg [7:0] uid_mem[0:UID_MAX-1][0:UID_LEN-1];
    reg [2:0] uid_count;  // number stored

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uid_count     <= 0;
            uid_allowed   <= 0;
            uid_added_ok  <= 0;
            uid_duplicate <= 0;
            uid_full      <= 0;
            for (i = 0; i < UID_MAX; i = i + 1)
                for (j = 0; j < UID_LEN; j = j + 1)
                    uid_mem[i][j] <= 8'h00;
        end else if (valid) begin
            uid_allowed   <= 0;
            uid_added_ok  <= 0;
            uid_duplicate <= 0;
            uid_full      <= 0;

            case (cmd)
                8'h10: begin // CMD_CHECK_UID
                    if (uid_count > 0)
                        uid_allowed <= 1; // for demo, allow if any UID stored
                    else
                        uid_allowed <= 0; // deny if empty
                end

                8'h11: begin // CMD_ADD_UID
                    if (uid_count >= UID_MAX) begin
                        uid_full <= 1; // storage full
                    end else begin
                        // check duplicates
                        integer found;
                        found = 0;
                        for (i = 0; i < uid_count; i = i + 1) begin
                            if (uid_mem[i][0] == 8'h55) begin
                                found = 1;
                            end
                        end
                        if (found) begin
                            uid_duplicate <= 1;
                        end else begin
                            // add dummy UID (just store 0x55 pattern)
                            uid_mem[uid_count][0] <= 8'h55;
                            uid_added_ok <= 1;
                            uid_count    <= uid_count + 1;
                        end
                    end
                end
            endcase
        end
    end
endmodule
