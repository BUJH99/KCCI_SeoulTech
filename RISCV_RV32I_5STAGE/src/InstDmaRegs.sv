/*
[MODULE_INFO_START]
Name: InstDmaRegs
Role: APB control and status registers for the instruction DMA loader
Summary:
  - Provides BootRom-visible START, status, error, entry, checksum, and byte-count registers
  - Controls UART DMA/CPU mode handoff and RX FIFO flush timing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstDmaRegs #(
  parameter bit P_UART_RESET_CPU_MODE = 1'b0
) (
  input  logic                iClk,
  input  logic                iRst,
  input  logic                iPsel,
  input  logic                iPenable,
  input  logic                iPwrite,
  input  logic [11:0]         iPaddr,
  input  logic [3:0]          iPstrb,
  input  logic [31:0]         iPwdata,
  input  logic                iStatusBusy,
  input  logic                iStatusDone,
  input  logic                iStatusErr,
  input  logic                iStatusAppValid,
  input  logic [7:0]          iErrCode,
  input  logic [31:0]         iLoadAddr,
  input  logic [31:0]         iByteCnt,
  input  logic [31:0]         iEntryAddr,
  input  logic [31:0]         iExpectedChecksum,
  input  logic [31:0]         iActualChecksum,
  input  logic [31:0]         iWordsWritten,
  input  logic                iUartTxIdle,

  output logic [31:0]         oPrdata,
  output logic                oPready,
  output logic                oPslverr,
  output logic                oCtrlArm,
  output logic                oCtrlClearErr,
  output rv32i_pkg::UartModeE oUartMode,
  output logic                oUartRxFlushReq
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_CTRL              = 12'h000;
  localparam logic [11:0] LP_REG_STATUS            = 12'h004;
  localparam logic [11:0] LP_REG_ERROR_CODE        = 12'h008;
  localparam logic [11:0] LP_REG_LOAD_ADDR         = 12'h00C;
  localparam logic [11:0] LP_REG_BYTE_COUNT        = 12'h010;
  localparam logic [11:0] LP_REG_ENTRY_ADDR        = 12'h014;
  localparam logic [11:0] LP_REG_EXPECTED_CHECKSUM = 12'h018;
  localparam logic [11:0] LP_REG_ACTUAL_CHECKSUM   = 12'h01C;
  localparam logic [11:0] LP_REG_WORDS_WRITTEN     = 12'h020;

  logic        AccessEn;
  logic        CtrlWrEn;
  logic [31:0] CtrlWord;
  logic [31:0] CtrlWrData;
  logic [31:0] StatusWord;
  logic        ArmedReg;
  logic        AutoArmReg;
  logic        AppModePending;
  logic        CtrlClearErrPulse;
  logic        RxFlushReqPulse;
  UartModeE    uartMode;

  assign AccessEn      = iPsel && iPenable && oPready;
  assign CtrlWrEn   = AccessEn && iPwrite && (iPaddr == LP_REG_CTRL);
  assign CtrlWord      = {28'd0, AppModePending, AutoArmReg, 1'b0, ArmedReg};
  assign CtrlWrData = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);
  assign StatusWord    = {26'd0, (uartMode == UART_MODE_CPU), iStatusAppValid,
                          iStatusErr, iStatusDone, iStatusBusy, ArmedReg};

  assign oPready          = 1'b1;
  assign oCtrlArm         = ArmedReg;
  assign oCtrlClearErr    = CtrlClearErrPulse;
  assign oUartMode        = uartMode;
  assign oUartRxFlushReq  = RxFlushReqPulse;

  always_comb begin
    oPrdata  = '0;
    oPslverr = 1'b0;

    if (AccessEn) begin
      unique case (iPaddr)
        LP_REG_CTRL: begin
          if (!iPwrite) begin
            oPrdata = CtrlWord;
          end
        end

        LP_REG_STATUS: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = StatusWord;
          end
        end

        LP_REG_ERROR_CODE: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = {24'd0, iErrCode};
          end
        end

        LP_REG_LOAD_ADDR: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = iLoadAddr;
          end
        end

        LP_REG_BYTE_COUNT: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = iByteCnt;
          end
        end

        LP_REG_ENTRY_ADDR: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = iEntryAddr;
          end
        end

        LP_REG_EXPECTED_CHECKSUM: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = iExpectedChecksum;
          end
        end

        LP_REG_ACTUAL_CHECKSUM: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = iActualChecksum;
          end
        end

        LP_REG_WORDS_WRITTEN: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = iWordsWritten;
          end
        end

        default: begin
          oPslverr = 1'b1;
        end
      endcase
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      ArmedReg          <= 1'b0;
      AutoArmReg        <= 1'b0;
      AppModePending    <= 1'b0;
      uartMode          <= P_UART_RESET_CPU_MODE ? UART_MODE_CPU : UART_MODE_DMA;
      CtrlClearErrPulse <= 1'b0;
      RxFlushReqPulse   <= 1'b0;
    end else begin
      CtrlClearErrPulse <= 1'b0;
      RxFlushReqPulse   <= 1'b0;

      if (CtrlWrEn) begin
        if (CtrlWrData[0]) begin
          ArmedReg        <= 1'b1;
          uartMode        <= UART_MODE_DMA;
          AppModePending  <= 1'b0;
          RxFlushReqPulse <= 1'b1;
        end

        if (CtrlWrData[1]) begin
          CtrlClearErrPulse <= 1'b1;
          ArmedReg          <= 1'b0;
        end

        AutoArmReg <= CtrlWrData[2];

        if (CtrlWrData[3]) begin
          AppModePending <= 1'b1;
        end
      end

      if (iStatusDone || iStatusErr) begin
        ArmedReg <= AutoArmReg && !iStatusErr;
      end

      if (AppModePending && iUartTxIdle) begin
        uartMode        <= UART_MODE_CPU;
        AppModePending  <= 1'b0;
        RxFlushReqPulse <= 1'b1;
      end
    end
  end

endmodule
