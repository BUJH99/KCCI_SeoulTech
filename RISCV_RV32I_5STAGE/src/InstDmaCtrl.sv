/*
[MODULE_INFO_START]
Name: InstDmaCtrl
Role: Instruction DMA packet parser and loader control FSM
Summary:
  - Parses RAXI loader packet headers and validates ProgramRam load ranges
  - Drives InstDmaData payload writes and emits UART ACK/ERR response bytes
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstDmaCtrl #(
  parameter int unsigned P_TIMEOUT_CYCLES = 0
) (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iCtrlArm,
  input  logic        iCtrlClearErr,
  input  logic        iRxValid,
  input  logic [7:0]  iRxData,
  input  logic        iTxReady,
  input  logic        iDataPayloadReady,
  input  logic [31:0] iDataActualChecksum,
  input  logic [31:0] iDataWordsWritten,

  output logic        oRxReady,
  output logic        oTxValid,
  output logic [7:0]  oTxData,
  output logic        oDataStart,
  output logic [31:0] oDataLoadAddr,
  output logic [31:0] oDataByteCnt,
  output logic        oDataPayloadValid,
  output logic [7:0]  oDataPayloadByte,
  output logic        oDataPayloadLast,
  output logic        oBusy,
  output logic        oDone,
  output logic        oErr,
  output logic        oAppValid,
  output logic [7:0]  oErrCode,
  output logic [31:0] oLoadAddr,
  output logic [31:0] oByteCnt,
  output logic [31:0] oEntryAddr,
  output logic [31:0] oExpectedChecksum,
  output logic [31:0] oActualChecksum,
  output logic [31:0] oWordsWritten
);

  import rv32i_pkg::*;

  localparam logic [7:0] LP_ACK_BYTE = 8'h06;
  localparam logic [7:0] LP_ERR_BYTE = 8'h15;

  localparam logic [7:0] LP_ERR_NONE       = 8'h00;
  localparam logic [7:0] LP_ERR_MAGIC      = 8'h01;
  localparam logic [7:0] LP_ERR_LOAD_RANGE = 8'h02;
  localparam logic [7:0] LP_ERR_COUNT      = 8'h03;
  localparam logic [7:0] LP_ERR_CHECKSUM   = 8'h04;
  localparam logic [7:0] LP_ERR_TIMEOUT    = 8'h05;

  typedef enum logic [3:0] {
    IDLE,
    HEADER,
    CONFIG,
    WAIT_DATA,
    VERIFY,
    SEND_ACK,
    DONE,
    SEND_ERR,
    ERROR
  } state_e;

  state_e state;
  state_e state_d;

  logic [4:0]  HeaderIdx;
  logic [31:0] PayloadByteIdx;
  logic [31:0] LoadAddr;
  logic [31:0] ByteCnt;
  logic [31:0] EntryAddr;
  logic [31:0] ExpectedChecksum;
  logic [31:0] EndAddr;
  logic [31:0] TimeoutCnt;
  logic [7:0]  ErrCode;
  logic        DoneReg;
  logic        ErrReg;
  logic        AppValidReg;
  logic        RxAccepted;
  logic        TxAccepted;
  logic        MagicMismatch;
  logic        PayloadLast;
  logic        CntInvalid;
  logic        RangeInvalid;
  logic        ChecksumMismatch;
  logic        TimeoutEnabled;
  logic        TimeoutHit;
  logic [31:0] TimeoutLimit;
  logic [7:0]  MagicByte;
  logic [7:0]  CfgErrCode;

  assign TimeoutEnabled = (P_TIMEOUT_CYCLES != 0);
  assign TimeoutLimit = 32'(P_TIMEOUT_CYCLES);
  assign TimeoutHit = TimeoutEnabled && (TimeoutCnt >= TimeoutLimit);
  assign RxAccepted = iRxValid && oRxReady;
  assign TxAccepted = oTxValid && iTxReady;
  assign PayloadLast = ((PayloadByteIdx + 32'd1) == ByteCnt);
  assign CntInvalid = (ByteCnt == 32'd0) || (ByteCnt[1:0] != 2'b00) || (LoadAddr[1:0] != 2'b00);
  assign EndAddr = LoadAddr + ByteCnt - 32'd1;
  assign RangeInvalid = (LoadAddr < LP_PROGRAM_RAM_BASE)
                     || (EndAddr > LP_PROGRAM_RAM_LAST)
                     || (EndAddr < LoadAddr);
  assign ChecksumMismatch = (iDataActualChecksum != ExpectedChecksum);
  assign CfgErrCode = CntInvalid ? LP_ERR_COUNT : LP_ERR_LOAD_RANGE;

  always_comb begin
    unique case (HeaderIdx)
      5'd0:    MagicByte = "R";
      5'd1:    MagicByte = "A";
      5'd2:    MagicByte = "X";
      5'd3:    MagicByte = "I";
      default: MagicByte = 8'h00;
    endcase
  end

  assign MagicMismatch = (state == HEADER) && RxAccepted && (HeaderIdx < 5'd4) && (iRxData != MagicByte);

  always_comb begin
    state_d = state;

    unique case (state)
      IDLE: begin
        if (iCtrlArm) begin
          state_d = HEADER;
        end
      end

      HEADER: begin
        if (MagicMismatch) begin
          state_d = SEND_ERR;
        end else if (RxAccepted && (HeaderIdx == 5'd19)) begin
          state_d = CONFIG;
        end else if (TimeoutHit) begin
          state_d = SEND_ERR;
        end
      end

      CONFIG: begin
        if (CntInvalid || RangeInvalid) begin
          state_d = SEND_ERR;
        end else begin
          state_d = WAIT_DATA;
        end
      end

      WAIT_DATA: begin
        if (RxAccepted && PayloadLast) begin
          state_d = VERIFY;
        end else if (TimeoutHit) begin
          state_d = SEND_ERR;
        end
      end

      VERIFY: begin
        if (ChecksumMismatch) begin
          state_d = SEND_ERR;
        end else begin
          state_d = SEND_ACK;
        end
      end

      SEND_ACK: begin
        if (TxAccepted) begin
          state_d = DONE;
        end
      end

      DONE: begin
        if (iCtrlClearErr) begin
          state_d = IDLE;
        end
      end

      SEND_ERR: begin
        if (TxAccepted) begin
          state_d = ERROR;
        end
      end

      ERROR: begin
        if (iCtrlClearErr) begin
          state_d = IDLE;
        end
      end

      default: begin
        state_d = IDLE;
      end
    endcase
  end

  // RX payload acceptance intentionally remains Mealy to preserve the byte-level DMA contract.
  always_comb begin
    oRxReady          = 1'b0;
    oTxValid          = 1'b0;
    oTxData           = LP_ERR_BYTE;
    oDataStart        = 1'b0;
    oDataLoadAddr     = LoadAddr;
    oDataByteCnt    = ByteCnt;
    oDataPayloadValid = 1'b0;
    oDataPayloadByte  = iRxData;
    oDataPayloadLast  = PayloadLast;
    oBusy             = 1'b0;
    oDone             = DoneReg;
    oErr            = ErrReg;
    oAppValid         = AppValidReg;
    oErrCode        = ErrCode;
    oLoadAddr         = LoadAddr;
    oByteCnt        = ByteCnt;
    oEntryAddr        = EntryAddr;
    oExpectedChecksum = ExpectedChecksum;
    oActualChecksum   = iDataActualChecksum;
    oWordsWritten     = iDataWordsWritten;

    unique case (state)
      HEADER: begin
        oRxReady = iCtrlArm;
        oBusy    = 1'b1;
      end

      CONFIG: begin
        oDataStart = !(CntInvalid || RangeInvalid);
        oBusy      = 1'b1;
      end

      WAIT_DATA: begin
        oRxReady          = iDataPayloadReady;
        oDataPayloadValid = RxAccepted;
        oBusy             = 1'b1;
      end

      VERIFY: begin
        oBusy = 1'b1;
      end

      SEND_ACK: begin
        oTxValid  = 1'b1;
        oTxData   = LP_ACK_BYTE;
        oBusy     = 1'b1;
        oDone     = 1'b1;
        oAppValid = 1'b1;
      end

      DONE: begin
        oDone     = 1'b1;
        oAppValid = 1'b1;
      end

      SEND_ERR: begin
        oTxValid = 1'b1;
        oBusy    = 1'b1;
        oErr   = 1'b1;
      end

      ERROR: begin
        oErr = 1'b1;
      end

      default: begin
      end
    endcase
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state            <= IDLE;
      HeaderIdx      <= '0;
      PayloadByteIdx <= '0;
      LoadAddr         <= '0;
      ByteCnt        <= '0;
      EntryAddr        <= '0;
      ExpectedChecksum <= '0;
      TimeoutCnt       <= '0;
      ErrCode        <= LP_ERR_NONE;
      DoneReg          <= 1'b0;
      ErrReg         <= 1'b0;
      AppValidReg      <= 1'b0;
    end else begin
      state <= state_d;

      if ((state == IDLE) && (state_d == HEADER)) begin
        HeaderIdx      <= '0;
        PayloadByteIdx <= '0;
        LoadAddr         <= '0;
        ByteCnt        <= '0;
        EntryAddr        <= '0;
        ExpectedChecksum <= '0;
        TimeoutCnt       <= '0;
        ErrCode        <= LP_ERR_NONE;
      end

      if ((state == HEADER) || (state == WAIT_DATA)) begin
        if (RxAccepted) begin
          TimeoutCnt <= '0;
        end else if (TimeoutEnabled) begin
          TimeoutCnt <= TimeoutCnt + 32'd1;
        end
      end else begin
        TimeoutCnt <= '0;
      end

      if ((state == HEADER) && RxAccepted && !MagicMismatch) begin
        HeaderIdx <= HeaderIdx + 5'd1;

        unique case (HeaderIdx)
          5'd4:  LoadAddr[7:0]            <= iRxData;
          5'd5:  LoadAddr[15:8]           <= iRxData;
          5'd6:  LoadAddr[23:16]          <= iRxData;
          5'd7:  LoadAddr[31:24]          <= iRxData;
          5'd8:  ByteCnt[7:0]           <= iRxData;
          5'd9:  ByteCnt[15:8]          <= iRxData;
          5'd10: ByteCnt[23:16]         <= iRxData;
          5'd11: ByteCnt[31:24]         <= iRxData;
          5'd12: EntryAddr[7:0]           <= iRxData;
          5'd13: EntryAddr[15:8]          <= iRxData;
          5'd14: EntryAddr[23:16]         <= iRxData;
          5'd15: EntryAddr[31:24]         <= iRxData;
          5'd16: ExpectedChecksum[7:0]    <= iRxData;
          5'd17: ExpectedChecksum[15:8]   <= iRxData;
          5'd18: ExpectedChecksum[23:16]  <= iRxData;
          5'd19: ExpectedChecksum[31:24]  <= iRxData;
          default: begin
          end
        endcase
      end

      if ((state == WAIT_DATA) && RxAccepted) begin
        PayloadByteIdx <= PayloadByteIdx + 32'd1;
      end

      if (MagicMismatch) begin
        ErrCode <= LP_ERR_MAGIC;
        ErrReg  <= 1'b1;
      end else if ((state == CONFIG) && (CntInvalid || RangeInvalid)) begin
        ErrCode <= CfgErrCode;
        ErrReg  <= 1'b1;
      end else if ((state == VERIFY) && ChecksumMismatch) begin
        ErrCode <= LP_ERR_CHECKSUM;
        ErrReg  <= 1'b1;
      end else if (((state == HEADER) || (state == WAIT_DATA)) && TimeoutHit) begin
        ErrCode <= LP_ERR_TIMEOUT;
        ErrReg  <= 1'b1;
      end else if ((state == VERIFY) && !ChecksumMismatch) begin
        DoneReg     <= 1'b1;
        AppValidReg <= 1'b1;
      end

      if (iCtrlClearErr) begin
        ErrCode <= LP_ERR_NONE;
        DoneReg   <= 1'b0;
        ErrReg  <= 1'b0;
        AppValidReg <= 1'b0;
      end
    end
  end

endmodule
