/*
[MODULE_INFO_START]
Name: I2cRegs
Role: APB register and IRQ-cause block for the compact I2C master
Summary:
  - Implements CTRL, STATUS, TXDATA, RXDATA, CLKDIV, ADDR, IRQ_STATUS, and IRQ_ENABLE
  - Tracks event and error cause bits with RW1C IRQ_STATUS behavior
  - Exposes separated event/error IRQ outputs for PLIC-lite routing
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cRegs (
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
  input  logic        iNackPulse,
  input  logic        iArbLostPulse,
  input  logic        iBusErrorPulse,

  output logic [31:0] oPrdata,
  output logic        oPslverr,
  output logic        oCtrlEnable,
  output logic        oCtrlStartPulse,
  output logic        oCtrlStop,
  output logic        oCtrlAck,
  output logic [7:0]  oTxData,
  output logic [15:0] oClkDiv,
  output logic [7:0]  oAddr,
  output logic        oEventIrq,
  output logic        oErrorIrq
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_CTRL       = 12'h000;
  localparam logic [11:0] LP_REG_STATUS     = 12'h004;
  localparam logic [11:0] LP_REG_TXDATA     = 12'h008;
  localparam logic [11:0] LP_REG_RXDATA     = 12'h00C;
  localparam logic [11:0] LP_REG_CLKDIV     = 12'h010;
  localparam logic [11:0] LP_REG_ADDR       = 12'h014;
  localparam logic [11:0] LP_REG_IRQ_STATUS = 12'h018;
  localparam logic [11:0] LP_REG_IRQ_ENABLE = 12'h01C;

  localparam logic [31:0] LP_EVENT_MASK = 32'h0000_000F;
  localparam logic [31:0] LP_ERROR_MASK = 32'h0000_0700;

  logic [31:0] CtrlWord;
  logic [31:0] StatusWord;
  logic [31:0] TxDataWord;
  logic [31:0] RxDataWord;
  logic [31:0] ClkDivWord;
  logic [31:0] AddrWord;
  logic [31:0] CtrlWriteWord;
  logic [31:0] TxDataWriteWord;
  logic [31:0] ClkDivWriteWord;
  logic [31:0] AddrWriteWord;
  logic [31:0] IrqStatusClearWord;
  logic [31:0] IrqEnableWriteWord;
  logic [31:0] IrqStatus;
  logic [31:0] IrqStatus_d;
  logic [31:0] IrqEnable;
  logic [31:0] IrqEnable_d;
  logic [31:0] CauseSetWord;

  assign CtrlWord           = {28'd0, oCtrlAck, oCtrlStop, 1'b0, oCtrlEnable};
  assign StatusWord         = {27'd0, |(IrqStatus & LP_ERROR_MASK), iTxReady, iRxValidPulse, iDonePulse, iBusy};
  assign TxDataWord         = {24'd0, oTxData};
  assign RxDataWord         = {24'd0, iRxData};
  assign ClkDivWord         = {16'd0, oClkDiv};
  assign AddrWord           = {24'd0, oAddr};
  assign CtrlWriteWord      = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);
  assign TxDataWriteWord    = ByteWriteMerge(TxDataWord, iPwdata, iPstrb);
  assign ClkDivWriteWord    = ByteWriteMerge(ClkDivWord, iPwdata, iPstrb);
  assign AddrWriteWord      = ByteWriteMerge(AddrWord, iPwdata, iPstrb);
  assign IrqStatusClearWord = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign IrqEnableWriteWord = ByteWriteMerge(IrqEnable, iPwdata, iPstrb);
  assign oCtrlStartPulse    = iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL) && CtrlWriteWord[1];
  assign oEventIrq          = |(IrqStatus & IrqEnable & LP_EVENT_MASK);
  assign oErrorIrq          = |(IrqStatus & IrqEnable & LP_ERROR_MASK);

  always_comb begin
    CauseSetWord     = '0;
    CauseSetWord[0]  = iDonePulse;
    CauseSetWord[1]  = iRxValidPulse;
    CauseSetWord[2]  = iTxReady;
    CauseSetWord[3]  = iDonePulse && oAddr[0];
    CauseSetWord[8]  = iNackPulse;
    CauseSetWord[9]  = iArbLostPulse;
    CauseSetWord[10] = iBusErrorPulse;
  end

  always_comb begin
    IrqStatus_d = (IrqStatus | CauseSetWord);
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

        LP_REG_ADDR: begin
          if (!iPwrite) begin
            oPrdata = AddrWord;
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
      oCtrlEnable <= 1'b0;
      oCtrlStop   <= 1'b0;
      oCtrlAck    <= 1'b1;
      oTxData     <= '0;
      oClkDiv     <= 16'd99;
      oAddr       <= '0;
      IrqStatus   <= '0;
      IrqEnable   <= '0;
    end else begin
      IrqStatus <= IrqStatus_d;
      IrqEnable <= IrqEnable_d;

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL)) begin
        oCtrlEnable <= CtrlWriteWord[0];
        oCtrlStop   <= CtrlWriteWord[2];
        oCtrlAck    <= CtrlWriteWord[3];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_TXDATA)) begin
        oTxData <= TxDataWriteWord[7:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CLKDIV)) begin
        oClkDiv <= ClkDivWriteWord[15:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_ADDR)) begin
        oAddr <= AddrWriteWord[7:0];
      end
    end
  end

endmodule
