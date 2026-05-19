/*
[MODULE_INFO_START]
Name: SpiRegs
Role: APB register, FIFO, and IRQ-cause block for the v1 SPI trace master
Summary:
  - Implements the documented CTRL/STATUS/TXDATA/RXDATA/CLKDIV/CS_CTRL/FRAME_LEN/IRQ map
  - Owns explicit 32-byte TX and RX FIFOs for 24-byte sort trace frames
  - Tracks event and error causes with RW1C IRQ_STATUS behavior
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module SpiRegs (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iAccessEn,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iBusy,
  input  logic        iDonePulse,
  input  logic        iTxUnderflowPulse,
  input  logic        iModeErrPulse,
  input  logic        iFrameDroppedPulse,
  input  logic        iTxFifoPopPulse,
  input  logic        iRxFifoPushPulse,
  input  logic [7:0]  iRxFifoPushData,

  output logic [31:0] oPrdata,
  output logic        oPslverr,
  output logic        oCtrlEn,
  output logic        oCtrlStartPulse,
  output logic        oCtrlCpol,
  output logic        oCtrlCpha,
  output logic        oCtrlLsbFirst,
  output logic [15:0] oClkDiv,
  output logic [7:0]  oCsCtrl,
  output logic [7:0]  oFrameLen,
  output logic [7:0]  oTxFifoData,
  output logic        oTxFifoValid,
  output logic        oEventIrq,
  output logic        oErrIrq
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_CTRL       = 12'h000;
  localparam logic [11:0] LP_REG_STATUS     = 12'h004;
  localparam logic [11:0] LP_REG_TXDATA     = 12'h008;
  localparam logic [11:0] LP_REG_RXDATA     = 12'h00C;
  localparam logic [11:0] LP_REG_CLKDIV     = 12'h010;
  localparam logic [11:0] LP_REG_CS_CTRL    = 12'h014;
  localparam logic [11:0] LP_REG_FRAME_LEN  = 12'h018;
  localparam logic [11:0] LP_REG_IRQ_STATUS = 12'h01C;
  localparam logic [11:0] LP_REG_IRQ_ENABLE = 12'h020;

  localparam int unsigned LP_FIFO_DEPTH = 32;
  localparam int unsigned LP_FIFO_PTR_W = 5;
  localparam logic [LP_FIFO_PTR_W:0] LP_FIFO_DEPTH_CNT = 6'd32;

  localparam logic [31:0] LP_EVENT_MASK = 32'h0000_0007;
  localparam logic [31:0] LP_ERROR_MASK = 32'h0000_0F00;
  localparam logic [7:0]  LP_DEFAULT_FRAME_LEN = 8'd24;

  logic [7:0] MemTxFifo [0:LP_FIFO_DEPTH-1];
  logic [7:0] MemRxFifo [0:LP_FIFO_DEPTH-1];

  logic [LP_FIFO_PTR_W-1:0] PtrTxWr;
  logic [LP_FIFO_PTR_W-1:0] PtrTxRd;
  logic [LP_FIFO_PTR_W-1:0] PtrRxWr;
  logic [LP_FIFO_PTR_W-1:0] PtrRxRd;
  logic [LP_FIFO_PTR_W:0]   CntTx;
  logic [LP_FIFO_PTR_W:0]   CntRx;

  logic [31:0] CtrlWord;
  logic [31:0] StatusWord;
  logic [31:0] RxDataWord;
  logic [31:0] ClkDivWord;
  logic [31:0] CsCtrlWord;
  logic [31:0] FrameLenWord;
  logic [31:0] CtrlWrWord;
  logic [31:0] TxDataWrWord;
  logic [31:0] ClkDivWrWord;
  logic [31:0] CsCtrlWrWord;
  logic [31:0] FrameLenWrWord;
  logic [31:0] IrqStatusClearWord;
  logic [31:0] IrqEnWrWord;
  logic [31:0] IrqStatus;
  logic [31:0] IrqStatus_d;
  logic [31:0] IrqEn;
  logic [31:0] IrqEn_d;
  logic [31:0] CauseSetWord;
  logic        TxFifoFull;
  logic        TxFifoEmpty;
  logic        RxFifoFull;
  logic        RxFifoEmpty;
  logic        TxPushPulse;
  logic        TxPushDo;
  logic        TxPopDo;
  logic        RxRdPulse;
  logic        RxRdDo;
  logic        RxPushDo;
  logic        RxOverflowPulse;
  logic        TxFifoClearPulse;
  logic        RxFifoClearPulse;

  assign TxFifoFull        = (CntTx == LP_FIFO_DEPTH_CNT);
  assign TxFifoEmpty       = (CntTx == '0);
  assign RxFifoFull        = (CntRx == LP_FIFO_DEPTH_CNT);
  assign RxFifoEmpty       = (CntRx == '0);
  assign TxPushPulse       = iAccessEn && iPwrite && (iPaddr == LP_REG_TXDATA);
  assign RxRdPulse       = iAccessEn && !iPwrite && (iPaddr == LP_REG_RXDATA);
  assign TxPushDo          = TxPushPulse && !TxFifoFull;
  assign TxPopDo           = iTxFifoPopPulse && !TxFifoEmpty;
  assign RxRdDo          = RxRdPulse && !RxFifoEmpty;
  assign RxPushDo          = iRxFifoPushPulse && !RxFifoFull;
  assign RxOverflowPulse   = iRxFifoPushPulse && RxFifoFull;
  assign TxFifoClearPulse  = iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL) && CtrlWrWord[2];
  assign RxFifoClearPulse  = iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL) && CtrlWrWord[3];
  assign oTxFifoData       = MemTxFifo[PtrTxRd];
  assign oTxFifoValid      = !TxFifoEmpty;

  assign CtrlWord           = {25'd0, oCtrlLsbFirst, oCtrlCpha, oCtrlCpol, 2'b00, 1'b0, oCtrlEn};
  assign StatusWord         = {26'd0, |(IrqStatus & LP_ERROR_MASK), IrqStatus[0], !RxFifoEmpty, TxFifoEmpty, !TxFifoFull, iBusy};
  assign RxDataWord         = RxFifoEmpty ? '0 : {24'd0, MemRxFifo[PtrRxRd]};
  assign ClkDivWord         = {16'd0, oClkDiv};
  assign CsCtrlWord         = {24'd0, oCsCtrl};
  assign FrameLenWord       = {24'd0, oFrameLen};
  assign CtrlWrWord      = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);
  assign TxDataWrWord    = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign ClkDivWrWord    = ByteWriteMerge(ClkDivWord, iPwdata, iPstrb);
  assign CsCtrlWrWord    = ByteWriteMerge(CsCtrlWord, iPwdata, iPstrb);
  assign FrameLenWrWord  = ByteWriteMerge(FrameLenWord, iPwdata, iPstrb);
  assign IrqStatusClearWord = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign IrqEnWrWord = ByteWriteMerge(IrqEn, iPwdata, iPstrb);
  assign oCtrlStartPulse    = iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL) && CtrlWrWord[1];
  assign oEventIrq          = |(IrqStatus & IrqEn & LP_EVENT_MASK);
  assign oErrIrq          = |(IrqStatus & IrqEn & LP_ERROR_MASK);

  always_comb begin
    CauseSetWord     = '0;
    CauseSetWord[0]  = iDonePulse;
    CauseSetWord[1]  = !TxFifoFull;
    CauseSetWord[2]  = !RxFifoEmpty;
    CauseSetWord[8]  = RxOverflowPulse;
    CauseSetWord[9]  = iTxUnderflowPulse;
    CauseSetWord[10] = iModeErrPulse;
    CauseSetWord[11] = iFrameDroppedPulse;
  end

  always_comb begin
    IrqStatus_d = IrqStatus | CauseSetWord;
    IrqEn_d = IrqEn;

    if (iAccessEn && iPwrite && (iPaddr == LP_REG_IRQ_STATUS)) begin
      IrqStatus_d = IrqStatus_d & ~IrqStatusClearWord;
    end

    if (iAccessEn && iPwrite && (iPaddr == LP_REG_IRQ_ENABLE)) begin
      IrqEn_d = IrqEnWrWord;
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
          if (!iPwrite || TxFifoFull) begin
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

        LP_REG_CS_CTRL: begin
          if (!iPwrite) begin
            oPrdata = CsCtrlWord;
          end
        end

        LP_REG_FRAME_LEN: begin
          if (!iPwrite) begin
            oPrdata = FrameLenWord;
          end
        end

        LP_REG_IRQ_STATUS: begin
          oPrdata = IrqStatus;
        end

        LP_REG_IRQ_ENABLE: begin
          if (!iPwrite) begin
            oPrdata = IrqEn;
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
      oCtrlEn   <= 1'b0;
      oCtrlCpol     <= 1'b0;
      oCtrlCpha     <= 1'b0;
      oCtrlLsbFirst <= 1'b0;
      oClkDiv       <= 16'd3;
      oCsCtrl       <= 8'h01;
      oFrameLen     <= LP_DEFAULT_FRAME_LEN;
      PtrTxWr       <= '0;
      PtrTxRd       <= '0;
      PtrRxWr       <= '0;
      PtrRxRd       <= '0;
      CntTx         <= '0;
      CntRx         <= '0;
      IrqStatus     <= '0;
      IrqEn     <= '0;
    end else begin
      IrqStatus <= IrqStatus_d;
      IrqEn <= IrqEn_d;

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL)) begin
        oCtrlEn   <= CtrlWrWord[0];
        oCtrlCpol     <= CtrlWrWord[4];
        oCtrlCpha     <= CtrlWrWord[5];
        oCtrlLsbFirst <= CtrlWrWord[6];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CLKDIV)) begin
        oClkDiv <= ClkDivWrWord[15:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CS_CTRL)) begin
        oCsCtrl <= CsCtrlWrWord[7:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_FRAME_LEN)) begin
        oFrameLen <= FrameLenWrWord[7:0];
      end

      if (TxFifoClearPulse) begin
        PtrTxWr <= '0;
        PtrTxRd <= '0;
        CntTx   <= '0;
      end else begin
        unique case ({TxPushDo, TxPopDo})
          2'b10: begin
            MemTxFifo[PtrTxWr] <= TxDataWrWord[7:0];
            PtrTxWr            <= PtrTxWr + 1'b1;
            CntTx              <= CntTx + 1'b1;
          end
          2'b01: begin
            PtrTxRd <= PtrTxRd + 1'b1;
            CntTx   <= CntTx - 1'b1;
          end
          2'b11: begin
            MemTxFifo[PtrTxWr] <= TxDataWrWord[7:0];
            PtrTxWr            <= PtrTxWr + 1'b1;
            PtrTxRd            <= PtrTxRd + 1'b1;
          end
          default: begin
          end
        endcase
      end

      if (RxFifoClearPulse) begin
        PtrRxWr <= '0;
        PtrRxRd <= '0;
        CntRx   <= '0;
      end else begin
        unique case ({RxPushDo, RxRdDo})
          2'b10: begin
            MemRxFifo[PtrRxWr] <= iRxFifoPushData;
            PtrRxWr            <= PtrRxWr + 1'b1;
            CntRx              <= CntRx + 1'b1;
          end
          2'b01: begin
            PtrRxRd <= PtrRxRd + 1'b1;
            CntRx   <= CntRx - 1'b1;
          end
          2'b11: begin
            MemRxFifo[PtrRxWr] <= iRxFifoPushData;
            PtrRxWr            <= PtrRxWr + 1'b1;
            PtrRxRd            <= PtrRxRd + 1'b1;
          end
          default: begin
          end
        endcase
      end
    end
  end

endmodule
