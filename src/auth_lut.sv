`timescale 1ns/1ps

module auth_lut #(
    parameter UID_MAX = 4,   // number of UIDs allowed
    parameter UID_LEN = 4    // each UID length (bytes)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] cmd,
    input  wire       valid,
    input  wire [8*16-1:0] uid_bytes_flat,  // received UID bytes from frame
    input  wire [7:0] uid_len,            // length of received UID
    output reg        uid_allowed,
    output reg        uid_added_ok,
    output reg        uid_duplicate,
    output reg        uid_full
);

    // Pack each UID (UID_LEN bytes) into one vector entry
    localparam MEMW = 8*UID_LEN;

    reg [MEMW-1:0] uid_mem [0:UID_MAX-1];
    reg [2:0]      uid_count;      // 0..UID_MAX (fits in 3 bits for UID_MAX<=8)

    integer i, j;
    integer found;
    reg match;
    reg [MEMW-1:0] received_uid;
    
    // local unpacked byte array
    reg [7:0] uid_bytes [0:15];

    // unpack flat → array
    always @(*) begin
        for (j = 0; j < 16; j = j + 1)
            uid_bytes[j] = uid_bytes_flat[j*8 +: 8];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uid_count     <= 0;
            uid_allowed   <= 0;
            uid_added_ok  <= 0;
            uid_duplicate <= 0;
            uid_full      <= 0;

            // reset memory (bounded by UID_MAX, not uid_count)
            for (i = 0; i < UID_MAX; i = i + 1)
                uid_mem[i] <= {MEMW{1'b0}};

        end else if (valid) begin
            // defaults each cycle when valid
            uid_allowed   <= 0;
            uid_added_ok  <= 0;
            uid_duplicate <= 0;
            uid_full      <= 0;

            // Pack received UID bytes into one vector
            received_uid = {MEMW{1'b0}};
            for (j = 0; j < UID_LEN; j = j + 1) begin
                if (j < uid_len)
                    received_uid[j*8 +: 8] = uid_bytes[j];
            end

            case (cmd)
                8'h10: begin
                    // CMD_CHECK_UID: search for matching UID
                    found = 0;
                    for (i = 0; i < UID_MAX; i = i + 1) begin
                        if (i < uid_count) begin
                            // Compare all bytes
                            match = 1;
                            for (j = 0; j < UID_LEN; j = j + 1) begin
                                if (uid_mem[i][j*8 +: 8] != received_uid[j*8 +: 8])
                                    match = 0;
                            end
                            if (match)
                                found = 1;
                        end
                    end
                    uid_allowed <= found;
                end

                8'h11: begin
                    // CMD_ADD_UID: check if full, duplicate, or add
                    if (uid_count >= UID_MAX) begin
                        uid_full <= 1'b1;   // storage full
                    end else begin
                        // Check for duplicate
                        found = 0;
                        for (i = 0; i < UID_MAX; i = i + 1) begin
                            if (i < uid_count) begin
                                match = 1;
                                for (j = 0; j < UID_LEN; j = j + 1) begin
                                    if (uid_mem[i][j*8 +: 8] != received_uid[j*8 +: 8])
                                        match = 0;
                                end
                                if (match)
                                    found = 1;
                            end
                        end

                        if (found) begin
                            uid_duplicate <= 1'b1;
                        end else begin
                            // Add the actual received UID
                            uid_mem[uid_count] <= received_uid;
                            uid_added_ok       <= 1'b1;
                            uid_count          <= uid_count + 1'b1;
                        end
                    end
                end

                default: begin
                    // no op
                end
            endcase
        end
    end
endmodule
