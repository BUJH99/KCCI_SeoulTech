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
  input  logic iRst,
  input  logic iRawIrq,
  input  logic iCompleteAccept,

  output logic oPendingSetPulse,
  output logic oBlocked
);

  typedef enum logic [1:0] {
    IDLE,
    PENDING_SET,
    BLOCKED
  } state_e;

  state_e state;
  state_e state_d;

  always_comb begin
    state_d = state;

    unique case (state)
      IDLE: begin
        if (iRawIrq) begin
          state_d = PENDING_SET;
        end
      end

      PENDING_SET: begin
        state_d = BLOCKED;
      end

      BLOCKED: begin
        if (iCompleteAccept) begin
          state_d = iRawIrq ? PENDING_SET : IDLE;
        end
      end

      default: begin
        state_d = IDLE;
      end
    endcase
  end

  always_comb begin
    oPendingSetPulse = 1'b0;
    oBlocked         = 1'b0;

    unique case (state)
      PENDING_SET: begin
        oPendingSetPulse = 1'b1;
      end

      BLOCKED: begin
        oBlocked = 1'b1;
      end

      default: begin
      end
    endcase
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state <= IDLE;
    end else begin
      state <= state_d;
    end
  end

endmodule
