`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: AXI_SLAVE
Role: AXI4-Lite slave register block
Summary:
  - AXI4-Lite slave with four 32-bit internal registers
  - Supports single-beat write and read transactions
StateDescription:
  - AW_IDLE/AW_READY: Write-address handshake staging
  - W_IDLE/W_READY: Write-data handshake staging
  - B_IDLE/B_VALID: Write-response return
  - AR_IDLE/AR_READY: Read-address handshake staging
  - R_IDLE/R_VALID: Read-data return
[MODULE_INFO_END]
*/

module AXI_SLAVE (
  input  logic         iClk,
  input  logic         iRstn,

  // AXI4-Lite write-address channel
  input  logic [31:0]  iSAwAddr,
  input  logic         iSAwValid,
  output logic         oSAwReady,

  // AXI4-Lite write-data channel
  input  logic [31:0]  iSWData,
  input  logic [3:0]   iSWStrb,
  input  logic         iSWValid,
  output logic         oSWReady,

  // AXI4-Lite write-response channel
  output logic [1:0]   oSBResp,
  output logic         oSBValid,
  input  logic         iSBReady,

  // AXI4-Lite read-address channel
  input  logic [31:0]  iSArAddr,
  input  logic         iSArValid,
  output logic         oSArReady,

  // AXI4-Lite read-data channel
  output logic [31:0]  oSRData,
  output logic [1:0]   oSRResp,
  output logic         oSRValid,
  input  logic         iSRReady
);

  localparam int         LP_SLV_REG_COUNT = 4;
  localparam logic [1:0] LP_AXI_RESP_OKAY = 2'b00;

  typedef enum logic {
    AW_IDLE,
    AW_READY
  } aw_state_e;

  typedef enum logic {
    W_IDLE,
    W_READY
  } w_state_e;

  typedef enum logic {
    B_IDLE,
    B_VALID
  } b_state_e;

  typedef enum logic {
    AR_IDLE,
    AR_READY
  } ar_state_e;

  typedef enum logic {
    R_IDLE,
    R_VALID
  } r_state_e;

  logic [31:0] slvReg [4];
  logic [1:0]  writeAddrIdx;
  logic [31:0] readData;
  logic        awDone;
  logic        wDone;
  logic        _unusedAddrBits;

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

  logic awHandshake;
  logic wHandshake;
  logic bHandshake;
  logic arHandshake;
  logic writeAccepted;
  logic writeAddrAcceptable;
  logic writeDataAcceptable;
  logic readAddrAcceptable;

  function automatic logic [31:0] applyWStrb(
    input logic [31:0] iOldData,
    input logic [31:0] iNewData,
    input logic [3:0]  iWStrb
  );
    begin
      applyWStrb = iOldData;

      if (iWStrb[0]) begin
        applyWStrb[7:0] = iNewData[7:0];
      end

      if (iWStrb[1]) begin
        applyWStrb[15:8] = iNewData[15:8];
      end

      if (iWStrb[2]) begin
        applyWStrb[23:16] = iNewData[23:16];
      end

      if (iWStrb[3]) begin
        applyWStrb[31:24] = iNewData[31:24];
      end
    end
  endfunction

  // Handshake and output decode
  assign awHandshake         = oSAwReady & iSAwValid;
  assign wHandshake          = oSWReady & iSWValid;
  assign bHandshake          = oSBValid & iSBReady;
  assign arHandshake         = oSArReady & iSArValid;
  assign writeAccepted       = awDone & wHandshake;
  assign writeAddrAcceptable = !awDone && (bState == B_IDLE);
  assign writeDataAcceptable = awDone && !wDone && (bState == B_IDLE);
  assign readAddrAcceptable  = (rState == R_IDLE);
  assign _unusedAddrBits     = &{1'b0, iSAwAddr[31:4], iSAwAddr[1:0], iSArAddr[31:4], iSArAddr[1:0]};

  assign oSAwReady = (awState == AW_READY);
  assign oSWReady  = (wState == W_READY);
  assign oSBResp   = LP_AXI_RESP_OKAY;
  assign oSBValid  = (bState == B_VALID);
  assign oSArReady = (arState == AR_READY);
  assign oSRData   = readData;
  assign oSRResp   = LP_AXI_RESP_OKAY;
  assign oSRValid  = (rState == R_VALID);

  // Next-state logic
  always_comb begin
    awState_d = awState;

    unique case (awState)
      AW_IDLE: begin
        if (iSAwValid && writeAddrAcceptable) begin
          awState_d = AW_READY;
        end
      end

      AW_READY: begin
        awState_d = AW_IDLE;
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
        if (iSWValid && writeDataAcceptable) begin
          wState_d = W_READY;
        end
      end

      W_READY: begin
        wState_d = W_IDLE;
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
        if (writeAccepted) begin
          bState_d = B_VALID;
        end
      end

      B_VALID: begin
        if (iSBReady) begin
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
        if (iSArValid && readAddrAcceptable) begin
          arState_d = AR_READY;
        end
      end

      AR_READY: begin
        arState_d = AR_IDLE;
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
          rState_d = R_VALID;
        end
      end

      R_VALID: begin
        if (iSRReady) begin
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

  // Register map and datapath
  always_ff @(posedge iClk) begin
    if (!iRstn) begin
      for (int idxReg = 0; idxReg < LP_SLV_REG_COUNT; idxReg++) begin
        slvReg[idxReg] <= '0;
      end
      writeAddrIdx <= '0;
      readData  <= '0;
      awDone    <= 1'b0;
      wDone     <= 1'b0;
    end
    else begin
      if (awHandshake) begin
        writeAddrIdx <= iSAwAddr[3:2];
        awDone       <= 1'b1;
        wDone        <= 1'b0;
      end

      if (wHandshake) begin
        slvReg[writeAddrIdx] <= applyWStrb(slvReg[writeAddrIdx], iSWData, iSWStrb);
        wDone                <= 1'b1;
      end

      if (bHandshake) begin
        awDone <= 1'b0;
        wDone  <= 1'b0;
      end

      if (arHandshake) begin
        readData <= slvReg[iSArAddr[3:2]];
      end
    end
  end

endmodule
