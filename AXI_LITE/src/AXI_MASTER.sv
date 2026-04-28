`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: AXI_MASTER
Role: AXI4-Lite master request sequencer
Summary:
  - AXI4-Lite master for single-beat read and write requests
  - Separates AW, W, B, AR, and R channel control with per-channel FSMs
  - Surfaces BRESP and RRESP status to the local side
StateDescription:
  - AW_IDLE/AW_VALID: Write-address valid generation
  - W_IDLE/W_VALID: Write-data valid generation
  - B_IDLE/B_READY: Write-response handshake
  - AR_IDLE/AR_VALID: Read-address valid generation
  - R_IDLE/R_READY: Read-data handshake
[MODULE_INFO_END]
*/

module AXI_MASTER (
  input  logic         iClk,
  input  logic         iRstn,

  // Local request interface
  input  logic         iTransfer,
  output logic         oReady,
  input  logic [31:0]  iAddr,
  input  logic [31:0]  iWData,
  input  logic         iWrite,
  output logic [31:0]  oRData,
  output logic [1:0]   oWriteResp,
  output logic         oWriteRespValid,
  output logic [1:0]   oReadResp,
  output logic         oReadRespValid,

  // AXI4-Lite write-address channel
  output logic [31:0]  oMAwAddr,
  output logic         oMAwValid,
  input  logic         iMAwReady,

  // AXI4-Lite write-data channel
  output logic [31:0]  oMWData,
  output logic [3:0]   oMWStrb,
  output logic         oMWValid,
  input  logic         iMWReady,

  // AXI4-Lite write-response channel
  input  logic [1:0]   iMBResp,
  input  logic         iMBValid,
  output logic         oMBReady,

  // AXI4-Lite read-address channel
  output logic [31:0]  oMArAddr,
  output logic         oMArValid,
  input  logic         iMArReady,

  // AXI4-Lite read-data channel
  input  logic [31:0]  iMRData,
  input  logic [1:0]   iMRResp,
  input  logic         iMRValid,
  output logic         oMRReady
);

  localparam logic [3:0] LP_AXI_STRB_ALL  = 4'hF;
  localparam logic [1:0] LP_AXI_RESP_OKAY = 2'b00;

  typedef enum logic {
    AW_IDLE,
    AW_VALID
  } aw_state_e;

  typedef enum logic {
    W_IDLE,
    W_VALID
  } w_state_e;

  typedef enum logic {
    B_IDLE,
    B_READY
  } b_state_e;

  typedef enum logic {
    AR_IDLE,
    AR_VALID
  } ar_state_e;

  typedef enum logic {
    R_IDLE,
    R_READY
  } r_state_e;

  logic [31:0] writeAddr;
  logic [31:0] writeData;
  logic [31:0] readAddr;
  logic [31:0] readData;
  logic        awDone;
  logic        wDone;

  aw_state_e awState;
  aw_state_e awState_d;
  w_state_e  wState;
  w_state_e  wState_d;
  b_state_e  bState;
  b_state_e  bState_d;
  ar_state_e arState;
  ar_state_e arState_d;
  r_state_e  rState;
  r_state_e  rState_d;

  logic writeReq;
  logic writeStart;
  logic awHandshake;
  logic wHandshake;
  logic bHandshake;
  logic writeBusy;
  logic allWriteAccepted;
  logic readReq;
  logic readStart;
  logic arHandshake;
  logic rHandshake;
  logic readBusy;
  logic masterBusy;

  // Request decode and output decode
  assign writeReq         = iTransfer & iWrite;
  assign writeBusy        = (awState != AW_IDLE) | (wState != W_IDLE) | (bState != B_IDLE);
  assign masterBusy       = writeBusy | readBusy;
  assign writeStart       = writeReq & ~masterBusy;
  assign awHandshake      = (awState == AW_VALID) & iMAwReady;
  assign wHandshake       = (wState == W_VALID) & iMWReady;
  assign allWriteAccepted = (awDone | awHandshake) & (wDone | wHandshake);
  assign bHandshake       = (bState == B_READY) & iMBValid;

  assign readReq         = iTransfer & ~iWrite;
  assign readBusy        = (arState != AR_IDLE) | (rState != R_IDLE);
  assign readStart       = readReq & ~masterBusy;
  assign arHandshake     = (arState == AR_VALID) & iMArReady;
  assign rHandshake      = (rState == R_READY) & iMRValid;

  assign oReady    = ~masterBusy;
  assign oRData    = readData;
  assign oMAwAddr  = writeAddr;
  assign oMAwValid = (awState == AW_VALID);
  assign oMWData   = writeData;
  assign oMWStrb   = LP_AXI_STRB_ALL;
  assign oMWValid  = (wState == W_VALID);
  assign oMBReady  = (bState == B_READY);
  assign oMArAddr  = readAddr;
  assign oMArValid = (arState == AR_VALID);
  assign oMRReady  = (rState == R_READY);

  // Next-state logic
  always_comb begin
    awState_d = awState;

    unique case (awState)
      AW_IDLE: begin
        if (writeStart) begin
          awState_d = AW_VALID;
        end
      end

      AW_VALID: begin
        if (iMAwReady) begin
          awState_d = AW_IDLE;
        end
      end

      default: begin
        awState_d = AW_IDLE;
      end
    endcase
  end

  always_comb begin
    wState_d = wState;

    unique case (wState)
      W_IDLE: begin
        if (writeStart) begin
          wState_d = W_VALID;
        end
      end

      W_VALID: begin
        if (iMWReady) begin
          wState_d = W_IDLE;
        end
      end

      default: begin
        wState_d = W_IDLE;
      end
    endcase
  end

  always_comb begin
    bState_d = bState;

    unique case (bState)
      B_IDLE: begin
        if (allWriteAccepted) begin
          bState_d = B_READY;
        end
      end

      B_READY: begin
        if (iMBValid) begin
          bState_d = B_IDLE;
        end
      end

      default: begin
        bState_d = B_IDLE;
      end
    endcase
  end

  always_comb begin
    arState_d = arState;

    unique case (arState)
      AR_IDLE: begin
        if (readStart) begin
          arState_d = AR_VALID;
        end
      end

      AR_VALID: begin
        if (iMArReady) begin
          arState_d = AR_IDLE;
        end
      end

      default: begin
        arState_d = AR_IDLE;
      end
    endcase
  end

  always_comb begin
    rState_d = rState;

    unique case (rState)
      R_IDLE: begin
        if (arHandshake) begin
          rState_d = R_READY;
        end
      end

      R_READY: begin
        if (iMRValid) begin
          rState_d = R_IDLE;
        end
      end

      default: begin
        rState_d = R_IDLE;
      end
    endcase
  end

  // State registers
  always_ff @(posedge iClk) begin
    if (!iRstn) begin
      awState <= AW_IDLE;
      wState  <= W_IDLE;
      bState  <= B_IDLE;
      arState <= AR_IDLE;
      rState  <= R_IDLE;
    end
    else begin
      awState <= awState_d;
      wState  <= wState_d;
      bState  <= bState_d;
      arState <= arState_d;
      rState  <= rState_d;
    end
  end

  // Transaction registers
  always_ff @(posedge iClk) begin
    if (!iRstn) begin
      writeAddr <= '0;
      writeData <= '0;
      readAddr  <= '0;
      readData  <= '0;
      oWriteResp <= LP_AXI_RESP_OKAY;
      oWriteRespValid <= 1'b0;
      oReadResp <= LP_AXI_RESP_OKAY;
      oReadRespValid <= 1'b0;
      awDone    <= 1'b0;
      wDone     <= 1'b0;
    end
    else begin
      if (writeStart) begin
        writeAddr       <= iAddr;
        writeData       <= iWData;
        oWriteResp      <= LP_AXI_RESP_OKAY;
        oWriteRespValid <= 1'b0;
        awDone          <= 1'b0;
        wDone           <= 1'b0;
      end

      if (readStart) begin
        readAddr       <= iAddr;
        oReadResp      <= LP_AXI_RESP_OKAY;
        oReadRespValid <= 1'b0;
      end

      if (awHandshake) begin
        awDone <= 1'b1;
      end

      if (wHandshake) begin
        wDone <= 1'b1;
      end

      if (bHandshake) begin
        oWriteResp      <= iMBResp;
        oWriteRespValid <= 1'b1;
        awDone          <= 1'b0;
        wDone           <= 1'b0;
      end

      if (rHandshake) begin
        readData       <= iMRData;
        oReadResp      <= iMRResp;
        oReadRespValid <= 1'b1;
      end
    end
  end

endmodule
