/*
[MODULE_INFO_START]
Name: IntcGateway
Role: Per-source interrupt gateway for PLIC-lite notification control
Summary:
  - Converts a level-style raw interrupt into a single pending-set pulse
  - Blocks repeated notifications for the same source until software writes COMPLETE
  - Reissues a pending-set pulse after COMPLETE when the raw interrupt level is still asserted
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module IntcGateway (
  input  logic iClk,
  input  logic iRstn,
  input  logic iRawIrq,
  input  logic iCompleteAccept,

  output logic oPendingSetPulse,
  output logic oBlocked
);

  logic Blocked;

  assign oBlocked = Blocked;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      Blocked          <= 1'b0;
      oPendingSetPulse <= 1'b0;
    end else begin
      oPendingSetPulse <= 1'b0;

      if (Blocked) begin
        if (iCompleteAccept) begin
          Blocked <= 1'b0;
        end
      end else if (iRawIrq) begin
        oPendingSetPulse <= 1'b1;
        Blocked          <= 1'b1;
      end
    end
  end

endmodule
