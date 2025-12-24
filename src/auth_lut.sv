`timescale 1ns/1ps
/*
 * UID Authorization Lookup Table (auth_lut)
 * -----------------------------------------
 * Stores and checks allowed UIDs for RFID authentication.
 *
 * Parameters:
 *   UID_MAX: Number of UIDs allowed in memory
 *   UID_LEN: Number of bytes per UID
 *
 * Inputs:
 *   clk            : System clock
 *   rst_n          : Active-low reset
 *   cmd            : Command (8'h10=check, 8'h11=add)
 *   valid          : Strobe to process command
 *   uid_bytes_flat : Flattened UID bytes from frame
 *   uid_len        : Length of received UID
 *
 * Outputs:
 *   uid_allowed    : High if UID is allowed
 *   uid_added_ok   : High if UID was added successfully
 *   uid_duplicate  : High if UID already exists
 *   uid_full       : High if memory is full
 */
module auth_lut #(
    parameter UID_MAX = 4,   // Number of UIDs allowed
    parameter UID_LEN = 4    // Each UID length (bytes)
)(
    input  wire       clk,              // System clock
    input  wire       rst_n,            // Active-low reset
    input  wire [7:0] cmd,              // Command (8'h10=check, 8'h11=add)
    input  wire       valid,            // Strobe to process command
    input  wire [8*16-1:0] uid_bytes_flat, // Received UID bytes (flattened)
    input  wire [7:0] uid_len,          // Length of received UID
    output reg        uid_allowed,      // High if UID is allowed
    output reg        uid_added_ok,     // High if UID was added
    output reg        uid_duplicate,    // High if UID already exists
    output reg        uid_full          // High if memory is full
);

    // Each UID is packed into a MEMW-bit vector
    localparam MEMW = 8*UID_LEN;

    reg [MEMW-1:0] uid_mem [0:UID_MAX-1]; // UID memory
    reg [1:0]      uid_count;             // Number of stored UIDs (0..UID_MAX)

    integer i, j;                         // Loop variables
    reg found;                            // Set if UID is found
    reg match;                            // Set if UID matches
    reg [MEMW-1:0] received_uid;          // Received UID packed
    
    // Local unpacked byte array for received UID
    reg [7:0] uid_bytes [0:15];

    // Unpack flat UID bytes into array for easier access
    always @(*) begin
        for (j = 0; j < 16; j = j + 1)
            uid_bytes[j] = uid_bytes_flat[j*8 +: 8];
    end

    // Main logic: reset, check, and add UIDs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uid_count     <= 0;
            uid_allowed   <= 0;
            uid_added_ok  <= 0;
            uid_duplicate <= 0;
            uid_full      <= 0;

            // Reset UID memory
            for (i = 0; i < UID_MAX; i = i + 1)
                uid_mem[i] <= {MEMW{1'b0}};

        end else if (valid) begin
            // Default outputs each cycle when valid
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
                8'h10: begin // CMD_CHECK_UID: search for matching UID
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
                    uid_allowed <= found;
                end

                8'h11: begin // CMD_ADD_UID: check if full, duplicate, or add
                    if (uid_count >= UID_MAX) begin
                        uid_full <= 1'b1;   // Storage full
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
