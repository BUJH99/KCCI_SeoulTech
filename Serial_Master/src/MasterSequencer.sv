/*
[MODULE_INFO_START]
Name: MasterSequencer
Role: High-level polling controller for the Master project
Summary:
  - Launches a write to register 0x01 followed by a read from register 0x02 every time the sticky poll timer expires
  - Updates the mirrored LED payload only after a full write/read transaction pair completes
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module MasterSequencer (
  input  logic               iClk,
  input  logic               iRst,
  input  logic               iTimerExpired,
  input  CommPkg::protocol_e iProtocolSel,
  input  logic [7:0]         iWriteData,
  input  logic               iTxnDone,
  input  logic [7:0]         iTxnRdData,
  output logic               oTimerClr,
  output logic               oCmdLoad,
  output logic               oTxnStart,
  output logic               oTxnRw,
  output logic [7:0]         oTxnRegAddr,
  output logic [7:0]         oTxnWrData,
  output CommPkg::protocol_e oTxnProtocol,
  output logic [6:0]         oLedMirror,
  output logic               oBusy
);

  import CommPkg::*;

  master_seq_state_e state, state_d;
  logic [7:0]        ReadbackData, ReadbackData_d;
  logic [6:0]        LedMirror, LedMirror_d;

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state        <= MASTER_SEQ_IDLE;
      ReadbackData <= '0;
      LedMirror    <= '0;
    end else begin
      state        <= state_d;
      ReadbackData <= ReadbackData_d;
      LedMirror    <= LedMirror_d;
    end
  end

  always_comb begin
    state_d        = state;
    ReadbackData_d = ReadbackData;
    LedMirror_d    = LedMirror;

    unique case (state)
      MASTER_SEQ_IDLE: begin
        if (iTimerExpired) begin
          state_d = MASTER_SEQ_WRITE_REQ;
        end
      end

      MASTER_SEQ_WRITE_REQ: begin
        state_d = MASTER_SEQ_WRITE_WAIT;
      end

      MASTER_SEQ_WRITE_WAIT: begin
        if (iTxnDone) begin
          state_d = MASTER_SEQ_READ_REQ;
        end
      end

      MASTER_SEQ_READ_REQ: begin
        state_d = MASTER_SEQ_READ_WAIT;
      end

      MASTER_SEQ_READ_WAIT: begin
        if (iTxnDone) begin
          ReadbackData_d = iTxnRdData;
          state_d        = MASTER_SEQ_COMMIT;
        end
      end

      MASTER_SEQ_COMMIT: begin
        LedMirror_d = ReadbackData[6:0];
        state_d     = MASTER_SEQ_IDLE;
      end

      default: begin
        state_d = MASTER_SEQ_IDLE;
      end
    endcase
  end

  always_comb begin
    oTimerClr    = 1'b0;
    oCmdLoad     = 1'b0;
    oTxnStart    = 1'b0;
    oTxnRw       = 1'b0;
    oTxnRegAddr  = '0;
    oTxnWrData   = '0;
    oTxnProtocol = iProtocolSel;
    oLedMirror   = LedMirror;
    oBusy        = (state != MASTER_SEQ_IDLE);

    unique case (state)
      MASTER_SEQ_IDLE: begin
        if (iTimerExpired) begin
          oCmdLoad = 1'b1;
        end
      end

      MASTER_SEQ_WRITE_REQ: begin
        oTxnStart   = 1'b1;
        oTxnRw      = 1'b0;
        oTxnRegAddr = LP_REG_WRITE;
        oTxnWrData  = iWriteData;
      end

      MASTER_SEQ_READ_REQ: begin
        oTxnStart   = 1'b1;
        oTxnRw      = 1'b1;
        oTxnRegAddr = LP_REG_READ;
        oTxnWrData  = 8'h00;
      end

      MASTER_SEQ_COMMIT: begin
        oTimerClr = 1'b1;
      end

      default: begin
      end
    endcase
  end

endmodule
