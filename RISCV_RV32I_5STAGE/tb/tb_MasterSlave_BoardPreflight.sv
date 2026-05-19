/*
[TB_INFO_START]
Name: TbTop
Target: APB_I2C/APB_SPI + SortDisplaySlaveTop
Role: Board-preflight simulation for the MASTER-to-SLAVE Bubble Sort link
Scenario:
  - Models the external open-drain I2C SDA/SCL lines used between two Basys3 boards
  - Drives APB transactions into the MASTER I2C/SPI peripherals
  - Checks that SLAVE I2C registers and SPI trace-frame capture work before hardware upload
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module TbTop;

  import sort_demo_pkg::*;

  localparam int unsigned LP_CLK_PERIOD_NS      = 10;
  localparam int unsigned LP_I2C_POLL_CYCLES    = 20_000;
  localparam int unsigned LP_SPI_POLL_CYCLES    = 10_000;
  localparam int unsigned LP_SLAVE_POLL_CYCLES  = 2_000;
  localparam logic [31:0] LP_SLAVE_ID           = 32'h534C_5631;

  localparam logic [11:0] LP_I2C_CTRL           = 12'h000;
  localparam logic [11:0] LP_I2C_STATUS         = 12'h004;
  localparam logic [11:0] LP_I2C_SLAVE_ADDR     = 12'h008;
  localparam logic [11:0] LP_I2C_REG_ADDR       = 12'h00C;
  localparam logic [11:0] LP_I2C_WDATA          = 12'h010;
  localparam logic [11:0] LP_I2C_RDATA          = 12'h014;
  localparam logic [11:0] LP_I2C_LEN            = 12'h018;
  localparam logic [11:0] LP_I2C_CLKDIV         = 12'h01C;
  localparam logic [11:0] LP_I2C_IRQ_STATUS     = 12'h020;

  localparam logic [31:0] LP_I2C_CTRL_ENABLE     = 32'h0000_0001;
  localparam logic [31:0] LP_I2C_CTRL_START      = 32'h0000_0002;
  localparam logic [31:0] LP_I2C_CTRL_RW         = 32'h0000_0004;
  localparam logic [31:0] LP_I2C_CTRL_CORE_RESET = 32'h0000_0008;
  localparam logic [31:0] LP_I2C_STATUS_DONE     = 32'h0000_0002;
  localparam logic [31:0] LP_I2C_STATUS_RX_VALID = 32'h0000_0008;
  localparam logic [31:0] LP_I2C_STATUS_ERROR    = 32'h0000_0010;

  localparam logic [11:0] LP_SPI_CTRL           = 12'h000;
  localparam logic [11:0] LP_SPI_STATUS         = 12'h004;
  localparam logic [11:0] LP_SPI_TXDATA         = 12'h008;
  localparam logic [11:0] LP_SPI_CLKDIV         = 12'h010;
  localparam logic [11:0] LP_SPI_CS_CTRL        = 12'h014;
  localparam logic [11:0] LP_SPI_FRAME_LEN      = 12'h018;
  localparam logic [11:0] LP_SPI_IRQ_STATUS     = 12'h01C;

  localparam logic [31:0] LP_SPI_CTRL_ENABLE      = 32'h0000_0001;
  localparam logic [31:0] LP_SPI_CTRL_START       = 32'h0000_0002;
  localparam logic [31:0] LP_SPI_CTRL_TX_FIFO_CLR = 32'h0000_0004;
  localparam logic [31:0] LP_SPI_CTRL_RX_FIFO_CLR = 32'h0000_0008;
  localparam logic [31:0] LP_SPI_STATUS_TX_READY  = 32'h0000_0002;
  localparam logic [31:0] LP_SPI_STATUS_DONE      = 32'h0000_0010;
  localparam logic [31:0] LP_SPI_STATUS_ERROR     = 32'h0000_0020;

  logic        iClk;
  logic        iRst;

  logic        i2cPsel;
  logic        i2cPenable;
  logic        i2cPwrite;
  logic [11:0] i2cPaddr;
  logic [3:0]  i2cPstrb;
  logic [31:0] i2cPwdata;
  logic [31:0] i2cPrdata;
  logic        i2cPready;
  logic        i2cPslverr;
  logic        i2cScl;
  logic        i2cSclOe;
  logic        i2cSdaOut;
  logic        i2cSdaOe;
  logic        i2cEventIrq;
  logic        i2cErrorIrq;

  logic        spiPsel;
  logic        spiPenable;
  logic        spiPwrite;
  logic [11:0] spiPaddr;
  logic [3:0]  spiPstrb;
  logic [31:0] spiPwdata;
  logic [31:0] spiPrdata;
  logic        spiPready;
  logic        spiPslverr;
  logic        spiSclk;
  logic        spiMosi;
  logic        spiCsN;
  logic        spiEventIrq;
  logic        spiErrorIrq;

  logic [6:0]  slaveSeg;
  logic        slaveDp;
  logic [3:0]  slaveDigitSel;

  tri1         sclLine;
  tri1         sdaLine;

  APB_I2C uMasterI2c (
    .iClk      (iClk),
    .iRst     (iRst),
    .iPsel     (i2cPsel),
    .iPenable  (i2cPenable),
    .iPwrite   (i2cPwrite),
    .iPaddr    (i2cPaddr),
    .iPstrb    (i2cPstrb),
    .iPwdata   (i2cPwdata),
    .iSdaIn    (sdaLine),
    .oPrdata   (i2cPrdata),
    .oPready   (i2cPready),
    .oPslverr  (i2cPslverr),
    .oScl      (i2cScl),
    .oSclOe    (i2cSclOe),
    .oSdaOut   (i2cSdaOut),
    .oSdaOe    (i2cSdaOe),
    .oEventIrq (i2cEventIrq),
    .oErrIrq (i2cErrorIrq)
  );

  APB_SPI uMasterSpi (
    .iClk      (iClk),
    .iRst     (iRst),
    .iPsel     (spiPsel),
    .iPenable  (spiPenable),
    .iPwrite   (spiPwrite),
    .iPaddr    (spiPaddr),
    .iPstrb    (spiPstrb),
    .iPwdata   (spiPwdata),
    .iMiso     (1'b0),
    .oPrdata   (spiPrdata),
    .oPready   (spiPready),
    .oPslverr  (spiPslverr),
    .oSclk     (spiSclk),
    .oMosi     (spiMosi),
    .oCsN      (spiCsN),
    .oEventIrq (spiEventIrq),
    .oErrIrq (spiErrorIrq)
  );

  SortDisplaySlaveTop #(
    .P_CLK_HZ (100_000_000)
  ) uSlave (
    .iClk        (iClk),
    .iRst       (iRst),
    .iSpiSclk    (spiSclk),
    .iSpiMosi    (spiMosi),
    .iSpiCsN     (spiCsN),
    .iI2cScl     (sclLine),
    .ioI2cSda    (sdaLine),
    .oSeg        (slaveSeg),
    .oDp         (slaveDp),
    .oDigitSel   (slaveDigitSel)
  );

  assign sclLine = (i2cSclOe && !i2cScl) ? 1'b0 : 1'bz;
  assign sdaLine = (i2cSdaOe && !i2cSdaOut) ? 1'b0 : 1'bz;

  initial begin : clock_gen
    iClk = 1'b0;
    forever #(LP_CLK_PERIOD_NS / 2) iClk = ~iClk;
  end

  initial begin : watchdog
    repeat (120_000) @(posedge iClk);
    $fatal(1, "[FAIL] Watchdog expired at sim_time_ns=%0t", $time);
  end

  initial begin : run_test
    ResetTb();
    RunI2cPreflight();
    RunSpiPreflight();
    RunI2cReadbackAfterSpi();
    $display("[PASS] MASTER/SLAVE board preflight completed at sim_time_ns=%0t", $time);
    $finish;
  end

  task automatic ResetTb;
    begin
      iRst      = 1'b1;
      i2cPsel    = 1'b0;
      i2cPenable = 1'b0;
      i2cPwrite  = 1'b0;
      i2cPaddr   = '0;
      i2cPstrb   = '0;
      i2cPwdata  = '0;
      spiPsel    = 1'b0;
      spiPenable = 1'b0;
      spiPwrite  = 1'b0;
      spiPaddr   = '0;
      spiPstrb   = '0;
      spiPwdata  = '0;
      repeat (12) @(posedge iClk);
      iRst = 1'b0;
      repeat (12) @(posedge iClk);
    end
  endtask

  task automatic CheckEq32(
    input logic [31:0] iActual,
    input logic [31:0] iExpected,
    input string       iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected 0x%08x, got 0x%08x", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic ApbI2cWrite(
    input logic [11:0] iAddr,
    input logic [31:0] iData
  );
    begin
      @(posedge iClk);
      i2cPsel    <= 1'b1;
      i2cPenable <= 1'b0;
      i2cPwrite  <= 1'b1;
      i2cPaddr   <= iAddr;
      i2cPstrb   <= 4'hF;
      i2cPwdata  <= iData;

      @(posedge iClk);
      i2cPenable <= 1'b1;

      @(posedge iClk);
      if (!i2cPready) begin
        $fatal(1, "[FAIL] I2C APB write did not complete immediately at addr=0x%03x", iAddr);
      end
      if (i2cPslverr) begin
        $fatal(1, "[FAIL] I2C APB write PSLVERR at addr=0x%03x data=0x%08x", iAddr, iData);
      end

      i2cPsel    <= 1'b0;
      i2cPenable <= 1'b0;
      i2cPwrite  <= 1'b0;
      i2cPaddr   <= '0;
      i2cPstrb   <= '0;
      i2cPwdata  <= '0;
    end
  endtask

  task automatic ApbI2cRead(
    input  logic [11:0] iAddr,
    output logic [31:0] oData
  );
    begin
      @(posedge iClk);
      i2cPsel    <= 1'b1;
      i2cPenable <= 1'b0;
      i2cPwrite  <= 1'b0;
      i2cPaddr   <= iAddr;
      i2cPstrb   <= 4'h0;
      i2cPwdata  <= '0;

      @(posedge iClk);
      i2cPenable <= 1'b1;

      @(posedge iClk);
      if (!i2cPready) begin
        $fatal(1, "[FAIL] I2C APB read did not complete immediately at addr=0x%03x", iAddr);
      end
      if (i2cPslverr) begin
        $fatal(1, "[FAIL] I2C APB read PSLVERR at addr=0x%03x", iAddr);
      end
      oData = i2cPrdata;

      i2cPsel    <= 1'b0;
      i2cPenable <= 1'b0;
      i2cPwrite  <= 1'b0;
      i2cPaddr   <= '0;
      i2cPstrb   <= '0;
      i2cPwdata  <= '0;
    end
  endtask

  task automatic ApbSpiWrite(
    input logic [11:0] iAddr,
    input logic [31:0] iData
  );
    begin
      @(posedge iClk);
      spiPsel    <= 1'b1;
      spiPenable <= 1'b0;
      spiPwrite  <= 1'b1;
      spiPaddr   <= iAddr;
      spiPstrb   <= 4'hF;
      spiPwdata  <= iData;

      @(posedge iClk);
      spiPenable <= 1'b1;

      @(posedge iClk);
      if (!spiPready) begin
        $fatal(1, "[FAIL] SPI APB write did not complete immediately at addr=0x%03x", iAddr);
      end
      if (spiPslverr) begin
        $fatal(1, "[FAIL] SPI APB write PSLVERR at addr=0x%03x data=0x%08x", iAddr, iData);
      end

      spiPsel    <= 1'b0;
      spiPenable <= 1'b0;
      spiPwrite  <= 1'b0;
      spiPaddr   <= '0;
      spiPstrb   <= '0;
      spiPwdata  <= '0;
    end
  endtask

  task automatic ApbSpiRead(
    input  logic [11:0] iAddr,
    output logic [31:0] oData
  );
    begin
      @(posedge iClk);
      spiPsel    <= 1'b1;
      spiPenable <= 1'b0;
      spiPwrite  <= 1'b0;
      spiPaddr   <= iAddr;
      spiPstrb   <= 4'h0;
      spiPwdata  <= '0;

      @(posedge iClk);
      spiPenable <= 1'b1;

      @(posedge iClk);
      if (!spiPready) begin
        $fatal(1, "[FAIL] SPI APB read did not complete immediately at addr=0x%03x", iAddr);
      end
      if (spiPslverr) begin
        $fatal(1, "[FAIL] SPI APB read PSLVERR at addr=0x%03x", iAddr);
      end
      oData = spiPrdata;

      spiPsel    <= 1'b0;
      spiPenable <= 1'b0;
      spiPwrite  <= 1'b0;
      spiPaddr   <= '0;
      spiPstrb   <= '0;
      spiPwdata  <= '0;
    end
  endtask

  task automatic I2cInit;
    begin
      ApbI2cWrite(LP_I2C_CLKDIV, 32'd7);
      ApbI2cWrite(LP_I2C_CTRL, LP_I2C_CTRL_ENABLE | LP_I2C_CTRL_CORE_RESET);
      ApbI2cWrite(LP_I2C_CTRL, LP_I2C_CTRL_ENABLE);
      ApbI2cWrite(LP_I2C_IRQ_STATUS, 32'hFFFF_FFFF);
    end
  endtask

  task automatic I2cWaitDone(
    input logic [31:0] iDoneMask,
    input string       iContext
  );
    logic [31:0] Status;
    logic [31:0] IrqStatus;
    int unsigned PollIdx;
    begin
      Status = '0;
      IrqStatus = '0;
      for (PollIdx = 0; PollIdx < LP_I2C_POLL_CYCLES; PollIdx = PollIdx + 1) begin
        ApbI2cRead(LP_I2C_STATUS, Status);
        if ((Status & LP_I2C_STATUS_ERROR) != 32'd0) begin
          ApbI2cRead(LP_I2C_IRQ_STATUS, IrqStatus);
          $fatal(1, "[FAIL] %s: I2C error status=0x%08x irq_status=0x%08x", iContext, Status, IrqStatus);
        end
        if ((Status & iDoneMask) == iDoneMask) begin
          return;
        end
      end
      ApbI2cRead(LP_I2C_IRQ_STATUS, IrqStatus);
      $fatal(
        1,
        "[FAIL] %s: I2C done mask 0x%08x not observed, last status=0x%08x irq_status=0x%08x",
        iContext,
        iDoneMask,
        Status,
        IrqStatus
      );
    end
  endtask

  task automatic I2cWriteReg(
    input logic [7:0]  iReg,
    input logic [31:0] iValue,
    input logic [2:0]  iLen
  );
    begin
      ApbI2cWrite(LP_I2C_IRQ_STATUS, 32'hFFFF_FFFF);
      ApbI2cWrite(LP_I2C_SLAVE_ADDR, {25'd0, SORT_SLAVE_I2C_ADDR});
      ApbI2cWrite(LP_I2C_REG_ADDR, {24'd0, iReg});
      ApbI2cWrite(LP_I2C_WDATA, iValue);
      ApbI2cWrite(LP_I2C_LEN, {29'd0, iLen});
      ApbI2cWrite(LP_I2C_CTRL, LP_I2C_CTRL_ENABLE | LP_I2C_CTRL_START);
      I2cWaitDone(LP_I2C_STATUS_DONE, $sformatf("I2C write reg 0x%02x", iReg));
    end
  endtask

  task automatic I2cReadReg(
    input  logic [7:0]  iReg,
    input  logic [2:0]  iLen,
    output logic [31:0] oValue
  );
    begin
      ApbI2cWrite(LP_I2C_IRQ_STATUS, 32'hFFFF_FFFF);
      ApbI2cWrite(LP_I2C_SLAVE_ADDR, {25'd0, SORT_SLAVE_I2C_ADDR});
      ApbI2cWrite(LP_I2C_REG_ADDR, {24'd0, iReg});
      ApbI2cWrite(LP_I2C_LEN, {29'd0, iLen});
      ApbI2cWrite(LP_I2C_CTRL, LP_I2C_CTRL_ENABLE | LP_I2C_CTRL_RW | LP_I2C_CTRL_START);
      I2cWaitDone(LP_I2C_STATUS_DONE | LP_I2C_STATUS_RX_VALID, $sformatf("I2C read reg 0x%02x", iReg));
      ApbI2cRead(LP_I2C_RDATA, oValue);
    end
  endtask

  task automatic SpiInit;
    begin
      ApbSpiWrite(LP_SPI_CLKDIV, 32'd1);
      ApbSpiWrite(LP_SPI_CS_CTRL, 32'd1);
      ApbSpiWrite(LP_SPI_FRAME_LEN, SORT_TRACE_FRAME_BYTES);
      ApbSpiWrite(LP_SPI_CTRL, LP_SPI_CTRL_ENABLE | LP_SPI_CTRL_TX_FIFO_CLR | LP_SPI_CTRL_RX_FIFO_CLR);
      ApbSpiWrite(LP_SPI_CTRL, LP_SPI_CTRL_ENABLE);
      ApbSpiWrite(LP_SPI_IRQ_STATUS, 32'hFFFF_FFFF);
    end
  endtask

  task automatic SpiWaitTxReady;
    logic [31:0] Status;
    int unsigned PollIdx;
    begin
      Status = '0;
      for (PollIdx = 0; PollIdx < LP_SPI_POLL_CYCLES; PollIdx = PollIdx + 1) begin
        ApbSpiRead(LP_SPI_STATUS, Status);
        if ((Status & LP_SPI_STATUS_ERROR) != 32'd0) begin
          $fatal(1, "[FAIL] SPI error while waiting TX_READY status=0x%08x", Status);
        end
        if ((Status & LP_SPI_STATUS_TX_READY) != 32'd0) begin
          return;
        end
      end
      $fatal(1, "[FAIL] SPI TX_READY not observed, last status=0x%08x", Status);
    end
  endtask

  task automatic SpiWaitFrameDone;
    logic [31:0] Status;
    int unsigned PollIdx;
    begin
      Status = '0;
      for (PollIdx = 0; PollIdx < LP_SPI_POLL_CYCLES; PollIdx = PollIdx + 1) begin
        ApbSpiRead(LP_SPI_STATUS, Status);
        if ((Status & LP_SPI_STATUS_ERROR) != 32'd0) begin
          $fatal(1, "[FAIL] SPI frame error status=0x%08x", Status);
        end
        if ((Status & LP_SPI_STATUS_DONE) != 32'd0) begin
          return;
        end
      end
      $fatal(1, "[FAIL] SPI frame done not observed, last status=0x%08x", Status);
    end
  endtask

  function automatic logic [7:0] TraceChecksum(input logic [7:0] iFrame [0:SORT_TRACE_FRAME_BYTES-1]);
    logic [7:0] Checksum;
    int unsigned Idx;
    begin
      Checksum = '0;
      for (Idx = 0; Idx < SORT_TRACE_FRAME_BYTES - 1; Idx = Idx + 1) begin
        Checksum = Checksum ^ iFrame[Idx];
      end
      TraceChecksum = Checksum;
    end
  endfunction

  task automatic BuildTraceFrame(
    output logic [7:0] oFrame [0:SORT_TRACE_FRAME_BYTES-1]
  );
    begin
      oFrame[0]  = SORT_FRAME_MAGIC0;
      oFrame[1]  = SORT_FRAME_MAGIC1;
      oFrame[2]  = SORT_FRAME_VERSION;
      oFrame[3]  = SORT_FRAME_TYPE_TRACE;
      oFrame[4]  = 8'h34;
      oFrame[5]  = 8'h12;
      oFrame[6]  = SORT_PHASE_DONE;
      oFrame[7]  = 8'h02;
      oFrame[8]  = 8'd5;
      oFrame[9]  = 8'd3;
      oFrame[10] = 8'd0;
      oFrame[11] = 8'd0;
      oFrame[12] = 8'd4;
      oFrame[13] = 8'd0;
      oFrame[14] = 8'd4;
      oFrame[15] = 8'hFF;
      oFrame[16] = 8'd7;
      oFrame[17] = 8'd0;
      oFrame[18] = 8'd2;
      oFrame[19] = 8'd0;
      oFrame[20] = 8'd9;
      oFrame[21] = 8'd0;
      oFrame[22] = 8'd0;
      oFrame[23] = TraceChecksum(oFrame);
    end
  endtask

  task automatic SpiSendTraceFrame(input logic [7:0] iFrame [0:SORT_TRACE_FRAME_BYTES-1]);
    int unsigned Idx;
    begin
      ApbSpiWrite(LP_SPI_IRQ_STATUS, 32'hFFFF_FFFF);
      ApbSpiWrite(LP_SPI_CTRL, LP_SPI_CTRL_ENABLE | LP_SPI_CTRL_TX_FIFO_CLR | LP_SPI_CTRL_RX_FIFO_CLR);
      ApbSpiWrite(LP_SPI_CTRL, LP_SPI_CTRL_ENABLE);

      for (Idx = 0; Idx < SORT_TRACE_FRAME_BYTES; Idx = Idx + 1) begin
        SpiWaitTxReady();
        ApbSpiWrite(LP_SPI_TXDATA, {24'd0, iFrame[Idx]});
      end

      ApbSpiWrite(LP_SPI_FRAME_LEN, SORT_TRACE_FRAME_BYTES);
      ApbSpiWrite(LP_SPI_CTRL, LP_SPI_CTRL_ENABLE | LP_SPI_CTRL_START);
      SpiWaitFrameDone();
    end
  endtask

  task automatic WaitForSlaveFrame;
    int unsigned PollIdx;
    begin
      for (PollIdx = 0; PollIdx < LP_SLAVE_POLL_CYCLES; PollIdx = PollIdx + 1) begin
        @(posedge iClk);
        if (uSlave.uSortSlaveRegs.oLastFrameId == 16'h1234) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] SLAVE did not accept SPI frame, lastFrameId=0x%04x errorCode=0x%04x",
        uSlave.uSortSlaveRegs.oLastFrameId,
        uSlave.uSortSlaveRegs.oErrCode
      );
    end
  endtask

  task automatic RunI2cPreflight;
    logic [31:0] ReadValue;
    begin
      I2cInit();

      I2cReadReg(SORT_SLAVE_REG_SLAVE_ID, 3'd4, ReadValue);
      CheckEq32(ReadValue, LP_SLAVE_ID, "SLAVE_ID I2C readback");

      I2cWriteReg(SORT_SLAVE_REG_BRIGHTNESS, 32'h0000_0005, 3'd1);
      I2cReadReg(SORT_SLAVE_REG_BRIGHTNESS, 3'd1, ReadValue);
      CheckEq32(ReadValue[7:0], 32'h0000_0005, "BRIGHTNESS I2C write/readback");

      I2cWriteReg(SORT_SLAVE_REG_DISPLAY_MODE, 32'h0000_0003, 3'd1);
      I2cReadReg(SORT_SLAVE_REG_DISPLAY_MODE, 3'd1, ReadValue);
      CheckEq32(ReadValue[7:0], 32'h0000_0003, "DISPLAY_MODE I2C write/readback");

      $display("[INFO] I2C preflight passed: slave_id=0x%08x brightness=%0d display_mode=%0d", LP_SLAVE_ID, 5, 3);
    end
  endtask

  task automatic RunSpiPreflight;
    logic [7:0] Frame [0:SORT_TRACE_FRAME_BYTES-1];
    begin
      SpiInit();
      BuildTraceFrame(Frame);
      SpiSendTraceFrame(Frame);
      WaitForSlaveFrame();

      CheckEq32({16'd0, uSlave.uSortSlaveRegs.oCompareCnt}, 32'd7, "SLAVE compare count after SPI frame");
      CheckEq32({16'd0, uSlave.uSortSlaveRegs.oSwapCnt}, 32'd2, "SLAVE swap count after SPI frame");
      CheckEq32({16'd0, uSlave.uSortSlaveRegs.oTotalCnt}, 32'd9, "SLAVE total count after SPI frame");
      CheckEq32({16'd0, uSlave.uSortSlaveRegs.oErrCode}, 32'd0, "SLAVE error code after SPI frame");

      $display("[INFO] SPI preflight passed: frame_id=0x%04x compare=%0d swap=%0d total=%0d",
        uSlave.uSortSlaveRegs.oLastFrameId,
        uSlave.uSortSlaveRegs.oCompareCnt,
        uSlave.uSortSlaveRegs.oSwapCnt,
        uSlave.uSortSlaveRegs.oTotalCnt
      );
    end
  endtask

  task automatic RunI2cReadbackAfterSpi;
    logic [31:0] ReadValue;
    begin
      I2cReadReg(SORT_SLAVE_REG_LAST_FRAME_ID, 3'd2, ReadValue);
      CheckEq32(ReadValue[15:0], 32'h0000_1234, "LAST_FRAME_ID I2C readback after SPI");

      I2cReadReg(SORT_SLAVE_REG_COMPARE_COUNT, 3'd2, ReadValue);
      CheckEq32(ReadValue[15:0], 32'd7, "COMPARE_COUNT I2C readback after SPI");

      I2cReadReg(SORT_SLAVE_REG_SWAP_COUNT, 3'd2, ReadValue);
      CheckEq32(ReadValue[15:0], 32'd2, "SWAP_COUNT I2C readback after SPI");

      I2cReadReg(SORT_SLAVE_REG_TOTAL_COUNT, 3'd2, ReadValue);
      CheckEq32(ReadValue[15:0], 32'd9, "TOTAL_COUNT I2C readback after SPI");

      $display("[INFO] I2C readback after SPI passed");
    end
  endtask

endmodule
