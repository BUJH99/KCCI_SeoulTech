/*
[MODULE_INFO_START]
Name: SpiRegs
Role: APB register and IRQ-cause block for the compact SPI master
Summary:
  - Implements CTRL, STATUS, TXDATA, RXDATA, CLKDIV, CS, IRQ_STATUS, and IRQ_ENABLE
  - Tracks event and error cause bits with RW1C IRQ_STATUS behavior
  - Exposes separated event/error IRQ outputs for PLIC-lite routing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiRegs (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iAccessEn,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iBusy,
  input  logic        iDonePulse,
  input  logic        iRxValidPulse,
  input  logic        iTxReady,
  input  logic [7:0]  iRxData,
  input  logic        iRxOverflowPulse,
  input  logic        iTxUnderflowPulse,
  input  logic        iModeErrorPulse,
  input  logic        iFrameDroppedPulse,

  output logic [31:0] oPrdata,
  output logic        oPslverr,
  output logic        oCtrlEnable,
  output logic        oCtrlStartPulse,
  output logic        oCtrlCpol,
  output logic        oCtrlCpha,
  output logic        oCtrlLsbFirst,
  output logic        oCtrlManualCs,
  output logic [7:0]  oTxData,
  output logic [15:0] oClkDiv,
  output logic [7:0]  oCsMask,
  output logic        oEventIrq,
  output logic        oErrorIrq
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_CTRL       = 12'h000;
  localparam logic [11:0] LP_REG_STATUS     = 12'h004;
  localparam logic [11:0] LP_REG_TXDATA     = 12'h008;
  localparam logic [11:0] LP_REG_RXDATA     = 12'h00C;
  localparam logic [11:0] LP_REG_CLKDIV     = 12'h010;
  localparam logic [11:0] LP_REG_CS         = 12'h014;
  localparam logic [11:0] LP_REG_IRQ_STATUS = 12'h018;
  localparam logic [11:0] LP_REG_IRQ_ENABLE = 12'h01C;

  localparam logic [31:0] LP_EVENT_MASK = 32'h0000_0007;
  localparam logic [31:0] LP_ERROR_MASK = 32'h0000_0F00;

  logic [31:0] CtrlWord;
  logic [31:0] StatusWord;
  logic [31:0] TxDataWord;
  logic [31:0] RxDataWord;
  logic [31:0] ClkDivWord;
  logic [31:0] CsWord;
  logic [31:0] CtrlWriteWord;
  logic [31:0] TxDataWriteWord;
  logic [31:0] ClkDivWriteWord;
  logic [31:0] CsWriteWord;
  logic [31:0] IrqStatusClearWord;
  logic [31:0] IrqEnableWriteWord;
  logic [31:0] IrqStatus;
  logic [31:0] IrqStatus_d;
  logic [31:0] IrqEnable;
  logic [31:0] IrqEnable_d;
  logic [31:0] CauseSetWord;

  assign CtrlWord           = {26'd0, oCtrlManualCs, oCtrlLsbFirst, oCtrlCpha, oCtrlCpol, 1'b0, oCtrlEnable};
  assign StatusWord         = {27'd0, |(IrqStatus & LP_ERROR_MASK), iRxValidPulse, iTxReady, iDonePulse, iBusy};
  assign TxDataWord         = {24'd0, oTxData};
  assign RxDataWord         = {24'd0, iRxData};
  assign ClkDivWord         = {16'd0, oClkDiv};
  assign CsWord             = {24'd0, oCsMask};
  assign CtrlWriteWord      = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);
  assign TxDataWriteWord    = ByteWriteMerge(TxDataWord, iPwdata, iPstrb);
  assign ClkDivWriteWord    = ByteWriteMerge(ClkDivWord, iPwdata, iPstrb);
  assign CsWriteWord        = ByteWriteMerge(CsWord, iPwdata, iPstrb);
  assign IrqStatusClearWord = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign IrqEnableWriteWord = ByteWriteMerge(IrqEnable, iPwdata, iPstrb);
  assign oCtrlStartPulse    = iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL) && CtrlWriteWord[1];
  assign oEventIrq          = |(IrqStatus & IrqEnable & LP_EVENT_MASK);
  assign oErrorIrq          = |(IrqStatus & IrqEnable & LP_ERROR_MASK);

  always_comb begin
    CauseSetWord     = '0;
    CauseSetWord[0]  = iDonePulse;
    CauseSetWord[1]  = iTxReady;
    CauseSetWord[2]  = iRxValidPulse;
    CauseSetWord[8]  = iRxOverflowPulse;
    CauseSetWord[9]  = iTxUnderflowPulse;
    CauseSetWord[10] = iModeErrorPulse;
    CauseSetWord[11] = iFrameDroppedPulse;
  end

  always_comb begin
    IrqStatus_d = IrqStatus | CauseSetWord;
    IrqEnable_d = IrqEnable;

    if (iAccessEn && iPwrite && (iPaddr == LP_REG_IRQ_STATUS)) begin
      IrqStatus_d = IrqStatus_d & ~IrqStatusClearWord;
    end

    if (iAccessEn && iPwrite && (iPaddr == LP_REG_IRQ_ENABLE)) begin
      IrqEnable_d = IrqEnableWriteWord;
    end
  end

  always_comb begin
    oPrdata  = '0;
    oPslverr = 1'b0;

    if (iAccessEn) begin
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

        LP_REG_TXDATA: begin
          if (!iPwrite) begin
            oPslverr = 1'b1;
          end
        end

        LP_REG_RXDATA: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = RxDataWord;
          end
        end

        LP_REG_CLKDIV: begin
          if (!iPwrite) begin
            oPrdata = ClkDivWord;
          end
        end

        LP_REG_CS: begin
          if (!iPwrite) begin
            oPrdata = CsWord;
          end
        end

        LP_REG_IRQ_STATUS: begin
          oPrdata = IrqStatus;
        end

        LP_REG_IRQ_ENABLE: begin
          if (!iPwrite) begin
            oPrdata = IrqEnable;
          end
        end

        default: begin
          oPslverr = 1'b1;
        end
      endcase
    end
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oCtrlEnable   <= 1'b0;
      oCtrlCpol     <= 1'b0;
      oCtrlCpha     <= 1'b0;
      oCtrlLsbFirst <= 1'b0;
      oCtrlManualCs <= 1'b0;
      oTxData       <= '0;
      oClkDiv       <= 16'd3;
      oCsMask       <= 8'h01;
      IrqStatus     <= '0;
      IrqEnable     <= '0;
    end else begin
      IrqStatus <= IrqStatus_d;
      IrqEnable <= IrqEnable_d;

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL)) begin
        oCtrlEnable   <= CtrlWriteWord[0];
        oCtrlCpol     <= CtrlWriteWord[2];
        oCtrlCpha     <= CtrlWriteWord[3];
        oCtrlLsbFirst <= CtrlWriteWord[4];
        oCtrlManualCs <= CtrlWriteWord[5];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_TXDATA)) begin
        oTxData <= TxDataWriteWord[7:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CLKDIV)) begin
        oClkDiv <= ClkDivWriteWord[15:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CS)) begin
        oCsMask <= CsWriteWord[7:0];
      end
    end
  end

endmodule
