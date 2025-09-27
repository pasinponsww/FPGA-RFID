// auth_lut.v
// -----------------------------------------------------------------------------
// Dummy UID LUT: always allow one UID, can extend for multiple.
// -----------------------------------------------------------------------------

module auth_lut (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] cmd,
    input  wire valid,
    output wire uid_allowed,
    output wire uid_added_ok,
    output wire uid_duplicate,
    output wire uid_full
);

    // for now: always return "allowed" and "added_ok"
    assign uid_allowed   = 1'b1;
    assign uid_added_ok  = 1'b1;
    assign uid_duplicate = 1'b0;
    assign uid_full      = 1'b0;

endmodule
