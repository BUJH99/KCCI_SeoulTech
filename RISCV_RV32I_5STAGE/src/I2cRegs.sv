/*
[MODULE_INFO_START]
Name: I2cRegs
Role: APB register and IRQ-cause block for the v1 I2C master
Summary:
  - Implements CTRL/STATUS/SLAVE_ADDR/REG_ADDR/WDATA/RDATA/LEN/CLKDIV/IRQ registers
  - Tracks DONE/RX_VALID/TX_READY and NACK/ARB_LOST/BUS_ERROR/TIMEOUT causes
  - Exposes a single latched transaction contract to the I2C bit-level core
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module I2cRegs (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iAccessEn,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iBusy,
  input  logic        iDonePulse,
  input  logic        iRxValidPulse,
  input  logic        iTxReady,
  input  logic        iAckOk,
  input  logic [31:0] iRxData,
  input  logic        iNackPulse,
  input  logic        iArbLostPulse,
  input  logic        iBusErrPulse,
  input  logic        iTimeoutPulse,

  output logic [31:0] oPrdata,
  output logic        oPslverr,
  output logic        oCtrlEn,
  output logic        oCtrlStartPulse,
  output logic        oCtrlRw,
  output logic        oStartRw,
  output logic        oCoreRstPulse,
  output logic [6:0]  oSlaveAddr,
  output logic [7:0]  oRegAddr,
  output logic [31:0] oWdata,
  output logic [2:0]  oLen,
  output logic [15:0] oClkDiv,
  output logic        oEventIrq,
  output logic        oErrIrq
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_CTRL       = 12'h000;
  localparam logic [11:0] LP_REG_STATUS     = 12'h004;
  localparam logic [11:0] LP_REG_SLAVE_ADDR = 12'h008;
  localparam logic [11:0] LP_REG_REG_ADDR   = 12'h00C;
  localparam logic [11:0] LP_REG_WDATA      = 12'h010;
  localparam logic [11:0] LP_REG_RDATA      = 12'h014;
  localparam logic [11:0] LP_REG_LEN        = 12'h018;
  localparam logic [11:0] LP_REG_CLKDIV     = 12'h01C;
  localparam logic [11:0] LP_REG_IRQ_STATUS = 12'h020;
  localparam logic [11:0] LP_REG_IRQ_ENABLE = 12'h024;

  localparam logic [31:0] LP_EVENT_MASK = 32'h0000_000F;
  localparam logic [31:0] LP_ERROR_MASK = 32'h0000_0F00;

  logic [31:0] CtrlWord;
  logic [31:0] StatusWord;
  logic [31:0] SlaveAddrWord;
  logic [31:0] RegAddrWord;
  logic [31:0] LenWord;
  logic [31:0] ClkDivWord;
  logic [31:0] CtrlWrWord;
  logic [31:0] SlaveAddrWrWord;
  logic [31:0] RegAddrWrWord;
  logic [31:0] WdataWrWord;
  logic [31:0] LenWrWord;
  logic [31:0] ClkDivWrWord;
  logic [31:0] IrqStatusClearWord;
  logic [31:0] IrqEnWrWord;
  logic [31:0] IrqStatus;
  logic [31:0] IrqStatus_d;
  logic [31:0] IrqEn;
  logic [31:0] IrqEn_d;
  logic [31:0] CauseSetWord;

  assign CtrlWord           = {28'd0, 1'b0, oCtrlRw, 1'b0, oCtrlEn};
  assign StatusWord         = {27'd0, |(IrqStatus & LP_ERROR_MASK), IrqStatus[1], iAckOk, IrqStatus[0], iBusy};
  assign SlaveAddrWord      = {25'd0, oSlaveAddr};
  assign RegAddrWord        = {24'd0, oRegAddr};
  assign LenWord            = {29'd0, oLen};
  assign ClkDivWord         = {16'd0, oClkDiv};
  assign CtrlWrWord      = ByteWriteMerge(CtrlWord, iPwdata, iPstrb);
  assign SlaveAddrWrWord = ByteWriteMerge(SlaveAddrWord, iPwdata, iPstrb);
  assign RegAddrWrWord   = ByteWriteMerge(RegAddrWord, iPwdata, iPstrb);
  assign WdataWrWord     = ByteWriteMerge(oWdata, iPwdata, iPstrb);
  assign LenWrWord       = ByteWriteMerge(LenWord, iPwdata, iPstrb);
  assign ClkDivWrWord    = ByteWriteMerge(ClkDivWord, iPwdata, iPstrb);
  assign IrqStatusClearWord = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign IrqEnWrWord = ByteWriteMerge(IrqEn, iPwdata, iPstrb);
  assign oCtrlStartPulse    = iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL) && CtrlWrWord[1];
  assign oStartRw           = oCtrlStartPulse ? CtrlWrWord[2] : oCtrlRw;
  assign oCoreRstPulse    = iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL) && CtrlWrWord[3];
  assign oEventIrq          = |(IrqStatus & IrqEn & LP_EVENT_MASK);
  assign oErrIrq          = |(IrqStatus & IrqEn & LP_ERROR_MASK);

  always_comb begin
    CauseSetWord     = '0;
    CauseSetWord[0]  = iDonePulse;
    CauseSetWord[1]  = iRxValidPulse;
    CauseSetWord[2]  = iTxReady;
    CauseSetWord[3]  = 1'b0;
    CauseSetWord[8]  = iNackPulse;
    CauseSetWord[9]  = iArbLostPulse;
    CauseSetWord[10] = iBusErrPulse;
    CauseSetWord[11] = iTimeoutPulse;
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

        LP_REG_SLAVE_ADDR: begin
          if (!iPwrite) begin
            oPrdata = SlaveAddrWord;
          end
        end

        LP_REG_REG_ADDR: begin
          if (!iPwrite) begin
            oPrdata = RegAddrWord;
          end
        end

        LP_REG_WDATA: begin
          if (!iPwrite) begin
            oPrdata = oWdata;
          end
        end

        LP_REG_RDATA: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = iRxData;
          end
        end

        LP_REG_LEN: begin
          if (!iPwrite) begin
            oPrdata = LenWord;
          end
        end

        LP_REG_CLKDIV: begin
          if (!iPwrite) begin
            oPrdata = ClkDivWord;
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
      oCtrlEn <= 1'b0;
      oCtrlRw     <= 1'b0;
      oSlaveAddr  <= 7'h42;
      oRegAddr    <= '0;
      oWdata      <= '0;
      oLen        <= 3'd1;
      oClkDiv     <= 16'd99;
      IrqStatus   <= '0;
      IrqEn   <= '0;
    end else begin
      IrqStatus <= IrqStatus_d;
      IrqEn <= IrqEn_d;

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CTRL)) begin
        oCtrlEn <= CtrlWrWord[0];
        oCtrlRw     <= CtrlWrWord[2];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_SLAVE_ADDR)) begin
        oSlaveAddr <= SlaveAddrWrWord[6:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_REG_ADDR)) begin
        oRegAddr <= RegAddrWrWord[7:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_WDATA)) begin
        oWdata <= WdataWrWord;
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_LEN)) begin
        oLen <= LenWrWord[2:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_CLKDIV)) begin
        oClkDiv <= ClkDivWrWord[15:0];
      end
    end
  end

endmodule
