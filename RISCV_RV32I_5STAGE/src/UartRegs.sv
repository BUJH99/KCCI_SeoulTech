/*
[MODULE_INFO_START]
Name: UartRegs
Role: APB-facing register and status block for the UART peripheral
Summary:
  - Stores UART control and IRQ-enable bits and tracks sticky RX overflow status
  - Implements APB readback, read/write decode, and request generation for TX write and RX read accesses
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module UartRegs (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iAccessEn,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iTxBusy,
  input  logic        iTxFifoFull,
  input  logic        iRxFifoEmpty,
  input  logic [7:0]  iRxFifoData,
  input  logic        iRxOverflowSet,

  output logic [31:0] oPrdata,
  output logic        oPslverr,
  output logic        oRxEn,
  output logic        oTxEn,
  output logic        oRxIrqEn,
  output logic        oRxOverflow,
  output logic        oTxDataWrReq,
  output logic        oRxDataRdReq
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_CTRL   = 12'h000;
  localparam logic [11:0] LP_REG_STATUS = 12'h004;
  localparam logic [11:0] LP_REG_TXDATA = 12'h008;
  localparam logic [11:0] LP_REG_RXDATA = 12'h00C;
  localparam logic [11:0] LP_REG_IRQ_EN = 12'h010;

  logic        CtrlWrEn;
  logic        IrqEnWrEn;
  logic [31:0] CtrlWord;
  logic [31:0] CtrlWordWrData;
  logic [31:0] StatusWord;
  logic [31:0] IrqEnWord;
  logic [31:0] IrqEnWordWrData;

  assign CtrlWord           = {30'd0, oTxEn, oRxEn};
  assign CtrlWordWrData  = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);
  assign StatusWord         = {28'd0, oRxOverflow, iTxBusy, !iTxFifoFull, !iRxFifoEmpty};
  assign IrqEnWord          = {31'd0, oRxIrqEn};
  assign IrqEnWordWrData = ByteWriteMerge(IrqEnWord, iPwdata, iPstrb);

  assign CtrlWrEn   = iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL);
  assign IrqEnWrEn  = iAccessEn && iPwrite && (iPaddr == LP_REG_IRQ_EN);
  assign oTxDataWrReq = iAccessEn && iPwrite && (iPaddr == LP_REG_TXDATA);
  assign oRxDataRdReq  = iAccessEn && !iPwrite && (iPaddr == LP_REG_RXDATA);

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
          if (iPwrite) begin
            oPslverr = iTxFifoFull;
          end else begin
            oPslverr = 1'b1;
          end
        end

        LP_REG_RXDATA: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata[7:0] = iRxFifoEmpty ? 8'd0 : iRxFifoData;
            oPslverr     = iRxFifoEmpty;
          end
        end

        LP_REG_IRQ_EN: begin
          if (!iPwrite) begin
            oPrdata = IrqEnWord;
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
      oRxEn       <= 1'b1;
      oTxEn       <= 1'b1;
      oRxIrqEn    <= 1'b0;
      oRxOverflow <= 1'b0;
    end else begin
      if (CtrlWrEn) begin
        oRxEn <= CtrlWordWrData[0];
        oTxEn <= CtrlWordWrData[1];
      end

      if (IrqEnWrEn) begin
        oRxIrqEn <= IrqEnWordWrData[0];
      end

      if (iRxOverflowSet) begin
        oRxOverflow <= 1'b1;
      end
    end
  end

endmodule
