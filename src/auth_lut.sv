// auth_lut.v
// Combinational "allow list" for 32-bit UIDs. Parameterize the list below.
`timescale 1ns/1ps
module auth_lut #(
    parameter [31:0] UID0 = 32'hDEADBEEF,
    parameter [31:0] UID1 = 32'h12345678,
    parameter [31:0] UID2 = 32'h00000000,
    parameter [31:0] UID3 = 32'h00000000
)(
    input  wire [31:0] uid,
    output wire        allowed
);
    assign allowed = (uid == UID0) |
                     (uid == UID1) |
                     (uid == UID2) |
                     (uid == UID3);
endmodule
