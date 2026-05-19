/*
[TB_INFO_START]
Name: TbTop
Target: TOP + SortDisplaySlaveTop
Role: Firmware-in-loop Bubble Sort end-to-end integration test
Scenario:
  - Loads the compiled RV32I Bubble Sort firmware through TOP's InstrRom parameter
  - Drives only external UART RX bytes and GPIO button inputs into MASTER TOP
  - Connects the separate SLAVE FPGA RTL through SPI and open-drain I2C wires
  - Checks UART reports, SPI trace frames, I2C register activity, AXI/APB bus coverage, FND activity, SLAVE counters, and interrupt cleanup
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module TbTop;

  import rv32i_pkg::*;
  import sort_demo_pkg::*;

  localparam int unsigned LP_CLK_PERIOD_NS       = 10;
  localparam int unsigned LP_CLK_HZ              = 100_000_000;
  localparam int unsigned LP_UART_BAUD           = 9_600;
  localparam int unsigned LP_UART_BIT_CYCLES     = LP_CLK_HZ / LP_UART_BAUD;
  localparam int unsigned LP_GPIO_WIDTH          = 8;
  localparam int unsigned LP_INSTR_ADDR_WIDTH    = 10;
  localparam int unsigned LP_DATA_ADDR_WIDTH     = 8;
  localparam int unsigned LP_WATCHDOG_CYCLES     = 80_000_000;
  localparam int unsigned LP_CASE_TIMEOUT_CYCLES = 8_000_000;
  localparam string       LP_FIRMWARE_MEM        = "../firmware/bubble_sort_demo.mem";
  localparam logic [1:0]  LP_AXI_RESP_OKAY       = 2'b00;
  localparam int unsigned LP_BUS_PERIPH_UART     = 0;
  localparam int unsigned LP_BUS_PERIPH_GPIO     = 1;
  localparam int unsigned LP_BUS_PERIPH_I2C      = 2;
  localparam int unsigned LP_BUS_PERIPH_INTC     = 3;
  localparam int unsigned LP_BUS_PERIPH_SPI      = 4;
  localparam int unsigned LP_BUS_PERIPH_FND      = 5;
  localparam int unsigned LP_BUS_PERIPH_TIMER    = 6;
  localparam int unsigned LP_BUS_PERIPH_COUNT    = 7;

  logic                    iClk;
  logic                    iRst;
  logic                    iUartRx;
  logic [LP_GPIO_WIDTH-1:0] iGpioIn;
  logic                    iSpiMiso;
  logic                    oUartTx;
  logic [LP_GPIO_WIDTH-1:0] oGpioOut;
  logic [LP_GPIO_WIDTH-1:0] oGpioOe;
  logic                    oSpiSclk;
  logic                    oSpiMosi;
  logic                    oSpiCsN;
  logic [6:0]              oSeg;
  logic                    oDp;
  logic [3:0]              oDigitSel;
  logic                    oTimingProbe;

  logic [6:0]              slaveSeg;
  logic                    slaveDp;
  logic [3:0]              slaveDigitSel;
  tri1                     sclLine;
  tri1                     sdaLine;

  string       uartRxText;
  int unsigned expectedSpiFrameId;
  int unsigned spiFrameCount;
  int unsigned spiLoadFrameCount;
  int unsigned spiCompareFrameCount;
  int unsigned spiSwapFrameCount;
  int unsigned spiPassDoneFrameCount;
  int unsigned spiDoneFrameCount;
  int unsigned spiPausedFrameCount;
  logic [7:0]  lastSpiPhase;
  logic [15:0] lastSpiFrameId;
  logic [15:0] lastSpiCompareCount;
  logic [15:0] lastSpiSwapCount;
  logic [15:0] lastSpiTotalCount;
  bit          i2cAddrMatchedSeen;
  bit          i2cSlaveIdReadSeen;
  bit          i2cBrightnessWriteSeen;
  bit          i2cDisplayModeWriteSeen;
  int unsigned i2cDisplayModeWriteCount;
  int unsigned i2cBrightnessWriteCount;
  int unsigned fndChangeCount;
  int unsigned slaveSelectedChangeCount;
  logic [15:0] lastFndDigits;
  logic [15:0] lastSlaveSelectedCount;
  bit          fndLastValid;
  bit          slaveSelectedLastValid;
  bit          uartTxWriteLast;
  bit          nativeApbInFlight;
  bit          busMonAwValid;
  bit          busMonWValid;
  bit          busMonAxiReqValid;
  bit          busMonAxiReqWrite;
  logic [31:0] busMonNativeAddr;
  logic [3:0]  busMonNativeStrb;
  logic [31:0] busMonNativeWdata;
  logic [31:0] busMonAwAddr;
  logic [3:0]  busMonWstrb;
  logic [31:0] busMonWdata;
  logic [31:0] busMonAxiReqAddr;
  logic [3:0]  busMonAxiReqStrb;
  logic [31:0] busMonAxiReqWdata;
  int unsigned nativeApbReqCount;
  int unsigned nativeApbReadReqCount;
  int unsigned nativeApbWriteReqCount;
  int unsigned axiWriteTxnCount;
  int unsigned axiReadTxnCount;
  int unsigned axiWriteRespCount;
  int unsigned axiReadRespCount;
  int unsigned axiErrorRespCount;
  int unsigned apbSetupCount;
  int unsigned apbAccessCycleCount;
  int unsigned apbCompleteCount;
  int unsigned apbReadCompleteCount [0:LP_BUS_PERIPH_COUNT-1];
  int unsigned apbWriteCompleteCount [0:LP_BUS_PERIPH_COUNT-1];

  TOP #(
    .P_CLK_HZ           (LP_CLK_HZ),
    .P_UART_BAUD        (LP_UART_BAUD),
    .P_GPIO_WIDTH       (LP_GPIO_WIDTH),
    .P_INSTR_ADDR_WIDTH (LP_INSTR_ADDR_WIDTH),
    .P_INSTR_INIT_FILE  (LP_FIRMWARE_MEM),
    .P_UART_RESET_CPU_MODE(1'b1),
    .P_DATA_ADDR_WIDTH  (LP_DATA_ADDR_WIDTH)
  ) dut (
    .iClk         (iClk),
    .iRst        (iRst),
    .iUartRx      (iUartRx),
    .iGpioIn      (iGpioIn),
    .iSpiMiso     (iSpiMiso),
    .ioI2cScl     (sclLine),
    .ioI2cSda     (sdaLine),
    .oUartTx      (oUartTx),
    .oGpioOut     (oGpioOut),
    .oGpioOe      (oGpioOe),
    .oSpiSclk     (oSpiSclk),
    .oSpiMosi     (oSpiMosi),
    .oSpiCsN      (oSpiCsN),
    .oSeg         (oSeg),
    .oDp          (oDp),
    .oDigitSel    (oDigitSel),
    .oTimingProbe (oTimingProbe)
  );

  SortDisplaySlaveTop #(
    .P_CLK_HZ (LP_CLK_HZ)
  ) uSlave (
    .iClk       (iClk),
    .iRst      (iRst),
    .iSpiSclk   (oSpiSclk),
    .iSpiMosi   (oSpiMosi),
    .iSpiCsN    (oSpiCsN),
    .iI2cScl    (sclLine),
    .ioI2cSda   (sdaLine),
    .oSeg       (slaveSeg),
    .oDp        (slaveDp),
    .oDigitSel  (slaveDigitSel)
  );

  assign iSpiMiso  = 1'b0;

  initial begin : clock_gen
    iClk = 1'b0;
    forever #(LP_CLK_PERIOD_NS / 2) iClk = ~iClk;
  end

  initial begin : watchdog
    repeat (LP_WATCHDOG_CYCLES) @(posedge iClk);
    $fatal(1, "[FAIL] Watchdog expired at sim_time_ns=%0t", $time);
  end

  initial begin : uart_tx_monitor
    forever begin
      @(posedge iClk);
      if (iRst) begin
        uartTxWriteLast = 1'b0;
      end else if (dut.uAPB_UART.TxDataWrReq && !uartTxWriteLast) begin
        uartRxText = {uartRxText, dut.uAPB_UART.iPwdata[7:0]};
      end
      uartTxWriteLast = !iRst && dut.uAPB_UART.TxDataWrReq;
    end
  end

  initial begin : axi_lite_apb_path_monitor
    bit          awNow;
    bit          wNow;
    bit          arNow;
    bit          bNow;
    bit          rNow;
    bit          nativeWrite;
    int unsigned pselCount;
    int unsigned periphIdx;

    forever begin
      @(posedge iClk);
      #1;

      if (iRst) begin
        ClearBusMonitorState();
      end else begin
        awNow      = dut.AxiAwvalid && dut.AxiAwready;
        wNow       = dut.AxiWvalid && dut.AxiWready;
        arNow      = dut.AxiArvalid && dut.AxiArready;
        bNow       = dut.AxiBvalid && dut.AxiBready;
        rNow       = dut.AxiRvalid && dut.AxiRready;
        nativeWrite = dut.ApbWr;

        if (dut.ApbSel && !nativeApbInFlight) begin
          if (!BusAddrInApbWindow(dut.BusAddr)) begin
            $fatal(1, "[FAIL] native APB-window request outside APB range addr=0x%08x", dut.BusAddr);
          end

          nativeApbInFlight   = 1'b1;
          busMonNativeAddr    = dut.BusAddr;
          busMonNativeStrb    = dut.BusByteEn;
          busMonNativeWdata   = dut.BusWdata;
          nativeApbReqCount++;
          if (nativeWrite) begin
            nativeApbWriteReqCount++;
          end else begin
            nativeApbReadReqCount++;
          end
        end

        if (awNow) begin
          busMonAwValid = 1'b1;
          busMonAwAddr  = dut.AxiAwaddr;
        end

        if (wNow) begin
          busMonWValid = 1'b1;
          busMonWstrb  = dut.AxiWstrb;
          busMonWdata  = dut.AxiWdata;
        end

        if (busMonAwValid && busMonWValid) begin
          busMonAxiReqValid = 1'b1;
          busMonAxiReqWrite = 1'b1;
          busMonAxiReqAddr  = busMonAwAddr;
          busMonAxiReqStrb  = busMonWstrb;
          busMonAxiReqWdata = busMonWdata;
          busMonAwValid     = 1'b0;
          busMonWValid      = 1'b0;
          axiWriteTxnCount++;
        end

        if (arNow) begin
          busMonAxiReqValid = 1'b1;
          busMonAxiReqWrite = 1'b0;
          busMonAxiReqAddr  = dut.AxiAraddr;
          busMonAxiReqStrb  = '0;
          busMonAxiReqWdata = '0;
          axiReadTxnCount++;
        end

        pselCount = BusPselCount();
        if (pselCount > 1) begin
          $fatal(
            1,
            "[FAIL] APB PSEL is not one-hot uart/gpio/i2c/intc/spi/fnd/timer=%0d/%0d/%0d/%0d/%0d/%0d/%0d",
            dut.UartPsel,
            dut.GpioPsel,
            dut.I2cPsel,
            dut.IntcPsel,
            dut.SpiPsel,
            dut.FndPsel,
            dut.TimerPsel
          );
        end

        if (pselCount != 0) begin
          periphIdx = BusSelectedPeriph();
          if (dut.ApbPenable) begin
            apbAccessCycleCount++;
            if (BusSelectedPready(periphIdx)) begin
              apbCompleteCount++;
              if (dut.ApbPwrite) begin
                apbWriteCompleteCount[periphIdx]++;
              end else begin
                apbReadCompleteCount[periphIdx]++;
              end
            end
          end else begin
            apbSetupCount++;
          end
        end

        if (bNow) begin
          if (dut.AxiBresp != LP_AXI_RESP_OKAY) begin
            axiErrorRespCount++;
            $fatal(1, "[FAIL] AXI B response returned error resp=0b%0b addr=0x%08x", dut.AxiBresp, busMonAxiReqAddr);
          end
          if (busMonAxiReqValid && busMonAxiReqWrite) begin
            axiWriteRespCount++;
            busMonAxiReqValid = 1'b0;
          end
        end

        if (rNow) begin
          if (dut.AxiRresp != LP_AXI_RESP_OKAY) begin
            axiErrorRespCount++;
            $fatal(1, "[FAIL] AXI R response returned error resp=0b%0b addr=0x%08x", dut.AxiRresp, busMonAxiReqAddr);
          end
          if (busMonAxiReqValid && !busMonAxiReqWrite) begin
            axiReadRespCount++;
            busMonAxiReqValid = 1'b0;
          end
        end

        if (nativeApbInFlight && dut.ApbRspReady) begin
          nativeApbInFlight = 1'b0;
        end
      end
    end
  end

  initial begin : spi_trace_monitor
    forever begin
      @(negedge oSpiCsN);
      if (!iRst) begin
        CaptureSpiFrame();
      end
    end
  end

  always @(posedge iClk) begin : scoreboard_pulse_monitor
    if (iRst) begin
      fndLastValid          <= 1'b0;
      slaveSelectedLastValid <= 1'b0;
    end else begin
      if (dut.uRv32iCore.TrapEnterValid
          && (dut.uRv32iCore.TrapEnterCause != 32'h8000_0007)
          && (dut.uRv32iCore.TrapEnterCause != 32'h8000_000B)) begin
        $fatal(
          1,
          "[FAIL] unexpected CPU trap pc=0x%08x cause=0x%08x",
          dut.uRv32iCore.Pc,
          dut.uRv32iCore.TrapEnterCause
        );
      end

      if (uSlave.uI2cSlaveRegTarget.addrMatched) begin
        i2cAddrMatchedSeen <= 1'b1;
      end

      if (uSlave.uI2cSlaveRegTarget.regPtrLoadPulse
          && (uSlave.uI2cSlaveRegTarget.regPtrLoadAddr == SORT_SLAVE_REG_SLAVE_ID)) begin
        i2cSlaveIdReadSeen <= 1'b1;
      end

      if (uSlave.DisplayModeWrEn) begin
        i2cDisplayModeWriteSeen  <= 1'b1;
        i2cDisplayModeWriteCount <= i2cDisplayModeWriteCount + 1;
      end

      if (uSlave.BrightnessWrEn) begin
        i2cBrightnessWriteSeen  <= 1'b1;
        i2cBrightnessWriteCount <= i2cBrightnessWriteCount + 1;
      end

      if (!fndLastValid) begin
        lastFndDigits <= dut.uAPB_FND.uFndRegs.oDigitsBcd;
        fndLastValid  <= 1'b1;
      end else if (lastFndDigits != dut.uAPB_FND.uFndRegs.oDigitsBcd) begin
        lastFndDigits  <= dut.uAPB_FND.uFndRegs.oDigitsBcd;
        fndChangeCount <= fndChangeCount + 1;
      end

      if (!slaveSelectedLastValid) begin
        lastSlaveSelectedCount  <= uSlave.uSortSlaveRegs.oSelCnt;
        slaveSelectedLastValid <= 1'b1;
      end else if (lastSlaveSelectedCount != uSlave.uSortSlaveRegs.oSelCnt) begin
        lastSlaveSelectedCount  <= uSlave.uSortSlaveRegs.oSelCnt;
        slaveSelectedChangeCount <= slaveSelectedChangeCount + 1;
      end
    end
  end

  function automatic logic [7:0] TraceChecksum(input logic [7:0] iFrame [0:SORT_TRACE_FRAME_BYTES-1]);
    logic [7:0] checksum;
    int unsigned idx;
    begin
      checksum = '0;
      for (idx = 0; idx < SORT_TRACE_FRAME_BYTES - 1; idx = idx + 1) begin
        checksum = checksum ^ iFrame[idx];
      end
      TraceChecksum = checksum;
    end
  endfunction

  function automatic bit UartTextContains(input string iExpected);
    int startIdx;
    int charIdx;
    bit matched;
    begin
      UartTextContains = 1'b0;
      if (iExpected.len() == 0) begin
        UartTextContains = 1'b1;
      end else if (uartRxText.len() >= iExpected.len()) begin
        for (startIdx = 0; startIdx <= uartRxText.len() - iExpected.len(); startIdx = startIdx + 1) begin
          matched = 1'b1;
          for (charIdx = 0; charIdx < iExpected.len(); charIdx = charIdx + 1) begin
            if (uartRxText[startIdx + charIdx] != iExpected[charIdx]) begin
              matched = 1'b0;
            end
          end
          if (matched) begin
            return 1'b1;
          end
        end
      end
    end
  endfunction

  function automatic bit BusAddrInApbWindow(input logic [31:0] iAddr);
    begin
      BusAddrInApbWindow = (iAddr >= LP_APB_BASE) && (iAddr <= LP_APB_LAST);
    end
  endfunction

  function automatic int unsigned BusPselCount;
    begin
      BusPselCount = int'(dut.UartPsel)
                   + int'(dut.GpioPsel)
                   + int'(dut.I2cPsel)
                   + int'(dut.IntcPsel)
                   + int'(dut.SpiPsel)
                   + int'(dut.FndPsel)
                   + int'(dut.TimerPsel);
    end
  endfunction

  function automatic int unsigned BusSelectedPeriph;
    begin
      if (dut.UartPsel) begin
        BusSelectedPeriph = LP_BUS_PERIPH_UART;
      end else if (dut.GpioPsel) begin
        BusSelectedPeriph = LP_BUS_PERIPH_GPIO;
      end else if (dut.I2cPsel) begin
        BusSelectedPeriph = LP_BUS_PERIPH_I2C;
      end else if (dut.IntcPsel) begin
        BusSelectedPeriph = LP_BUS_PERIPH_INTC;
      end else if (dut.SpiPsel) begin
        BusSelectedPeriph = LP_BUS_PERIPH_SPI;
      end else if (dut.FndPsel) begin
        BusSelectedPeriph = LP_BUS_PERIPH_FND;
      end else begin
        BusSelectedPeriph = LP_BUS_PERIPH_TIMER;
      end
    end
  endfunction

  function automatic bit BusSelectedPready(input int unsigned iPeriphIdx);
    begin
      unique case (iPeriphIdx)
        LP_BUS_PERIPH_UART: BusSelectedPready = dut.UartPready;
        LP_BUS_PERIPH_GPIO: BusSelectedPready = dut.GpioPready;
        LP_BUS_PERIPH_I2C:  BusSelectedPready = dut.I2cPready;
        LP_BUS_PERIPH_INTC: BusSelectedPready = dut.IntcPready;
        LP_BUS_PERIPH_SPI:  BusSelectedPready = dut.SpiPready;
        LP_BUS_PERIPH_FND:  BusSelectedPready = dut.FndPready;
        LP_BUS_PERIPH_TIMER: BusSelectedPready = dut.TimerPready;
        default:            BusSelectedPready = 1'b0;
      endcase
    end
  endfunction

  function automatic string BusPeriphName(input int unsigned iPeriphIdx);
    begin
      unique case (iPeriphIdx)
        LP_BUS_PERIPH_UART: BusPeriphName = "UART";
        LP_BUS_PERIPH_GPIO: BusPeriphName = "GPIO";
        LP_BUS_PERIPH_I2C:  BusPeriphName = "I2C";
        LP_BUS_PERIPH_INTC: BusPeriphName = "INTC";
        LP_BUS_PERIPH_SPI:  BusPeriphName = "SPI";
        LP_BUS_PERIPH_FND:  BusPeriphName = "FND";
        LP_BUS_PERIPH_TIMER: BusPeriphName = "TIMER";
        default:            BusPeriphName = "UNKNOWN";
      endcase
    end
  endfunction

  task automatic WaitCycles(input int unsigned iCycles);
    int unsigned idx;
    begin
      for (idx = 0; idx < iCycles; idx = idx + 1) begin
        @(posedge iClk);
      end
    end
  endtask

  task automatic ResetScoreboard;
    int unsigned periphIdx;
    begin
      uartRxText                 = "";
      expectedSpiFrameId         = 0;
      spiFrameCount              = 0;
      spiLoadFrameCount          = 0;
      spiCompareFrameCount       = 0;
      spiSwapFrameCount          = 0;
      spiPassDoneFrameCount      = 0;
      spiDoneFrameCount          = 0;
      spiPausedFrameCount        = 0;
      lastSpiPhase               = '0;
      lastSpiFrameId             = '0;
      lastSpiCompareCount        = '0;
      lastSpiSwapCount           = '0;
      lastSpiTotalCount          = '0;
      i2cAddrMatchedSeen         = 1'b0;
      i2cSlaveIdReadSeen         = 1'b0;
      i2cBrightnessWriteSeen     = 1'b0;
      i2cDisplayModeWriteSeen    = 1'b0;
      i2cDisplayModeWriteCount   = 0;
      i2cBrightnessWriteCount    = 0;
      fndChangeCount             = 0;
      slaveSelectedChangeCount   = 0;
      lastFndDigits              = '0;
      lastSlaveSelectedCount     = '0;
      fndLastValid               = 1'b0;
      slaveSelectedLastValid     = 1'b0;
      uartTxWriteLast            = 1'b0;
      nativeApbReqCount          = 0;
      nativeApbReadReqCount      = 0;
      nativeApbWriteReqCount     = 0;
      axiWriteTxnCount           = 0;
      axiReadTxnCount            = 0;
      axiWriteRespCount          = 0;
      axiReadRespCount           = 0;
      axiErrorRespCount          = 0;
      apbSetupCount              = 0;
      apbAccessCycleCount        = 0;
      apbCompleteCount           = 0;
      for (periphIdx = 0; periphIdx < LP_BUS_PERIPH_COUNT; periphIdx = periphIdx + 1) begin
        apbReadCompleteCount[periphIdx]  = 0;
        apbWriteCompleteCount[periphIdx] = 0;
      end
      ClearBusMonitorState();
    end
  endtask

  task automatic ClearBusMonitorState;
    begin
      nativeApbInFlight  = 1'b0;
      busMonAwValid      = 1'b0;
      busMonWValid       = 1'b0;
      busMonAxiReqValid  = 1'b0;
      busMonAxiReqWrite  = 1'b0;
      busMonNativeAddr   = '0;
      busMonNativeStrb   = '0;
      busMonNativeWdata  = '0;
      busMonAwAddr       = '0;
      busMonWstrb        = '0;
      busMonWdata        = '0;
      busMonAxiReqAddr   = '0;
      busMonAxiReqStrb   = '0;
      busMonAxiReqWdata  = '0;
    end
  endtask

  task automatic ResetSpiScoreboard;
    begin
      expectedSpiFrameId    = 0;
      spiFrameCount         = 0;
      spiLoadFrameCount     = 0;
      spiCompareFrameCount  = 0;
      spiSwapFrameCount     = 0;
      spiPassDoneFrameCount = 0;
      spiDoneFrameCount     = 0;
      spiPausedFrameCount   = 0;
      lastSpiPhase          = '0;
      lastSpiFrameId        = '0;
      lastSpiCompareCount   = '0;
      lastSpiSwapCount      = '0;
      lastSpiTotalCount     = '0;
    end
  endtask

  task automatic ResetDuts;
    begin
      iRst   = 1'b1;
      iUartRx = 1'b1;
      iGpioIn = '0;
      ResetScoreboard();
      WaitCycles(40);
      iRst = 1'b0;
      WaitCycles(20);
    end
  endtask

  task automatic CaptureUartTxByte(output logic [7:0] oByte);
    int unsigned bitIdx;
    begin
      @(negedge oUartTx);
      WaitCycles(LP_UART_BIT_CYCLES + (LP_UART_BIT_CYCLES / 2));
      for (bitIdx = 0; bitIdx < 8; bitIdx = bitIdx + 1) begin
        oByte[bitIdx] = oUartTx;
        WaitCycles(LP_UART_BIT_CYCLES);
      end
      WaitCycles(LP_UART_BIT_CYCLES);
    end
  endtask

  task automatic UartSendByte(input logic [7:0] iByte);
    int unsigned bitIdx;
    begin
      iUartRx = 1'b0;
      WaitCycles(LP_UART_BIT_CYCLES);
      for (bitIdx = 0; bitIdx < 8; bitIdx = bitIdx + 1) begin
        iUartRx = iByte[bitIdx];
        WaitCycles(LP_UART_BIT_CYCLES);
      end
      iUartRx = 1'b1;
      WaitCycles(LP_UART_BIT_CYCLES * 2);
    end
  endtask

  task automatic UartSendString(input string iText);
    int unsigned idx;
    begin
      for (idx = 0; idx < iText.len(); idx = idx + 1) begin
        UartSendByte(iText[idx]);
      end
    end
  endtask

  task automatic GpioPulse(input int unsigned iBitIdx);
    begin
      iGpioIn[iBitIdx] = 1'b0;
      WaitCycles(200);
      iGpioIn[iBitIdx] = 1'b1;
      WaitCycles(20_000);
      iGpioIn[iBitIdx] = 1'b0;
      WaitCycles(2_000);
    end
  endtask

  task automatic WaitForFirmwareReady(input string iContext);
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < LP_CASE_TIMEOUT_CYCLES; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if (i2cAddrMatchedSeen && i2cSlaveIdReadSeen && i2cBrightnessWriteSeen && i2cDisplayModeWriteSeen) begin
          $display("[INFO] %s firmware ready at sim_time_ns=%0t", iContext, $time);
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s firmware init not observed: addr=%0d slave_id=%0d brightness=%0d display=%0d",
        iContext,
        i2cAddrMatchedSeen,
        i2cSlaveIdReadSeen,
        i2cBrightnessWriteSeen,
        i2cDisplayModeWriteSeen
      );
    end
  endtask

  task automatic WaitForUartText(
    input string       iExpected,
    input int unsigned iTimeoutCycles,
    input string       iContext
  );
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < iTimeoutCycles; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if (UartTextContains(iExpected)) begin
          return;
        end
      end
      $fatal(1, "[FAIL] %s UART text not observed. expected='%s' got='%s'", iContext, iExpected, uartRxText);
    end
  endtask

  task automatic WaitForLoadCount(input int unsigned iExpectedCount, input string iContext);
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < LP_CASE_TIMEOUT_CYCLES; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if (spiLoadFrameCount >= iExpectedCount) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s load count not observed expected=%0d load_frames=%0d gpio_irq=0x%0x",
        iContext,
        iExpectedCount,
        spiLoadFrameCount,
        dut.uAPB_GPIO.IrqStatus
      );
    end
  endtask

  task automatic WaitForSortState(input string iContext);
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < LP_CASE_TIMEOUT_CYCLES; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if (spiCompareFrameCount != 0) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s sorting activity not observed load_frames=%0d compare_frames=%0d",
        iContext,
        spiLoadFrameCount,
        spiCompareFrameCount
      );
    end
  endtask

  task automatic WaitForMasterFnd(
    input logic [15:0] iExpectedDigits,
    input int unsigned iTimeoutCycles,
    input string       iContext
  );
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < iTimeoutCycles; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if (dut.uAPB_FND.uFndRegs.oDigitsBcd == iExpectedDigits) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s MASTER FND mismatch expected=0x%04x got=0x%04x",
        iContext,
        iExpectedDigits,
        dut.uAPB_FND.uFndRegs.oDigitsBcd
      );
    end
  endtask

  task automatic WaitForSpiDone(input string iContext);
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < LP_CASE_TIMEOUT_CYCLES; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if (spiDoneFrameCount != 0) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s TRACE_DONE not observed pc=0x%08x state=%0d len=%0d pass=%0d cmp_idx=%0d frame_id=%0d spi_frames=%0d load/cmp/swap/pass/done=%0d/%0d/%0d/%0d/%0d gpio_irq=0x%0x intc_pending=0x%0x intc_in_service=0x%0x intc_enable=0x%0x intc_selected=%0d uart='%s'",
        iContext,
        dut.uRv32iCore.Pc,
        dut.uDataRam.MemRam[10],
        dut.uDataRam.MemRam[7],
        dut.uDataRam.MemRam[6],
        dut.uDataRam.MemRam[5],
        dut.uDataRam.MemRam[1],
        spiFrameCount,
        spiLoadFrameCount,
        spiCompareFrameCount,
        spiSwapFrameCount,
        spiPassDoneFrameCount,
        spiDoneFrameCount,
        dut.uAPB_GPIO.IrqStatus,
        dut.uInterruptController.PendingVec,
        dut.uInterruptController.InServiceVec,
        dut.uInterruptController.EnVec,
        dut.uInterruptController.oSelSrcId,
        uartRxText
      );
    end
  endtask

  task automatic WaitForSpiPaused(input string iContext);
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < LP_CASE_TIMEOUT_CYCLES; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if (spiPausedFrameCount != 0) begin
          return;
        end
      end
      $fatal(1, "[FAIL] %s TRACE_PAUSED not observed", iContext);
    end
  endtask

  task automatic WaitForInterruptClean(input string iContext);
    int unsigned waitIdx;
    begin
      for (waitIdx = 0; waitIdx < 100_000; waitIdx = waitIdx + 1) begin
        @(posedge iClk);
        if ((dut.uInterruptController.PendingVec == '0)
            && (dut.uInterruptController.InServiceVec == '0)
            && (dut.uAPB_I2C.uI2cRegs.IrqStatus[11:8] == '0)
            && (dut.uAPB_SPI.uSpiRegs.IrqStatus[11:8] == '0)) begin
          return;
        end
      end
      $fatal(
        1,
        "[FAIL] %s interrupt/error state not clean pending=0x%0x in_service=0x%0x i2c_irq=0x%08x spi_irq=0x%08x",
        iContext,
        dut.uInterruptController.PendingVec,
        dut.uInterruptController.InServiceVec,
        dut.uAPB_I2C.uI2cRegs.IrqStatus,
        dut.uAPB_SPI.uSpiRegs.IrqStatus
      );
    end
  endtask

  task automatic CaptureSpiFrame;
    logic [7:0] frame [0:SORT_TRACE_FRAME_BYTES-1];
    logic [7:0] shiftByte;
    int unsigned byteIdx;
    int unsigned bitIdx;
    begin
      byteIdx   = 0;
      bitIdx    = 0;
      shiftByte = '0;

      while (!oSpiCsN) begin
        @(posedge oSpiSclk or posedge oSpiCsN);
        if (!oSpiCsN) begin
          shiftByte = {shiftByte[6:0], oSpiMosi};
          bitIdx = bitIdx + 1;
          if (bitIdx == 8) begin
            if (byteIdx < SORT_TRACE_FRAME_BYTES) begin
              frame[byteIdx] = shiftByte;
            end
            byteIdx   = byteIdx + 1;
            bitIdx    = 0;
            shiftByte = '0;
          end
        end
      end

      if ((byteIdx != SORT_TRACE_FRAME_BYTES) || (bitIdx != 0)) begin
        $fatal(1, "[FAIL] SPI short/long frame byte_count=%0d partial_bits=%0d", byteIdx, bitIdx);
      end

      ValidateSpiFrame(frame);
    end
  endtask

  task automatic ValidateSpiFrame(input logic [7:0] iFrame [0:SORT_TRACE_FRAME_BYTES-1]);
    logic [15:0] frameId;
    begin
      if ((iFrame[0] != SORT_FRAME_MAGIC0)
          || (iFrame[1] != SORT_FRAME_MAGIC1)
          || (iFrame[2] != SORT_FRAME_VERSION)
          || (iFrame[3] != SORT_FRAME_TYPE_TRACE)) begin
        $fatal(1, "[FAIL] SPI frame header mismatch %02x %02x %02x %02x", iFrame[0], iFrame[1], iFrame[2], iFrame[3]);
      end

      if (iFrame[23] != TraceChecksum(iFrame)) begin
        $fatal(1, "[FAIL] SPI frame checksum mismatch frame_id_lsb=0x%02x", iFrame[4]);
      end

      frameId = {iFrame[5], iFrame[4]};
      if (frameId != expectedSpiFrameId[15:0]) begin
        $fatal(1, "[FAIL] SPI frame id mismatch expected=%0d got=%0d", expectedSpiFrameId, frameId);
      end
      if (iFrame[8] != 8'd4) begin
        $fatal(1, "[FAIL] SPI frame array length expected=4 got=%0d", iFrame[8]);
      end

      expectedSpiFrameId   = expectedSpiFrameId + 1;
      spiFrameCount        = spiFrameCount + 1;
      lastSpiFrameId       = frameId;
      lastSpiPhase         = iFrame[6];
      lastSpiCompareCount  = {iFrame[17], iFrame[16]};
      lastSpiSwapCount     = {iFrame[19], iFrame[18]};
      lastSpiTotalCount    = {iFrame[21], iFrame[20]};

      unique case (iFrame[6])
        SORT_PHASE_LOAD:      spiLoadFrameCount++;
        SORT_PHASE_COMPARE:   spiCompareFrameCount++;
        SORT_PHASE_SWAP:      spiSwapFrameCount++;
        SORT_PHASE_PASS_DONE: spiPassDoneFrameCount++;
        SORT_PHASE_DONE:      spiDoneFrameCount++;
        SORT_PHASE_PAUSED:    spiPausedFrameCount++;
        default: begin
        end
      endcase
    end
  endtask

  task automatic CheckFinalState(
    input string       iContext,
    input string       iExpectedText,
    input int unsigned iExpectedCompare,
    input int unsigned iExpectedSwap,
    input int unsigned iExpectedTotal,
    input logic [15:0] iExpectedFndDigits,
    input int unsigned iDisplayModeBase
  );
    begin
      WaitForSpiDone(iContext);
      WaitForUartText(iExpectedText, LP_CASE_TIMEOUT_CYCLES, iContext);
      WaitForInterruptClean(iContext);

      if (spiDoneFrameCount != 1) begin
        $fatal(1, "[FAIL] %s expected one TRACE_DONE, got %0d", iContext, spiDoneFrameCount);
      end
      if (lastSpiPhase != SORT_PHASE_DONE) begin
        $fatal(1, "[FAIL] %s final SPI phase is not TRACE_DONE: 0x%02x", iContext, lastSpiPhase);
      end
      if ((lastSpiCompareCount != iExpectedCompare[15:0])
          || (lastSpiSwapCount != iExpectedSwap[15:0])
          || (lastSpiTotalCount != iExpectedTotal[15:0])) begin
        $fatal(
          1,
          "[FAIL] %s SPI final counts compare/swap/total expected=%0d/%0d/%0d got=%0d/%0d/%0d",
          iContext,
          iExpectedCompare,
          iExpectedSwap,
          iExpectedTotal,
          lastSpiCompareCount,
          lastSpiSwapCount,
          lastSpiTotalCount
        );
      end

      if ((uSlave.uSortSlaveRegs.oCompareCnt != iExpectedCompare[15:0])
          || (uSlave.uSortSlaveRegs.oSwapCnt != iExpectedSwap[15:0])
          || (uSlave.uSortSlaveRegs.oTotalCnt != iExpectedTotal[15:0])
          || (uSlave.uSortSlaveRegs.oLastFrameId != lastSpiFrameId)) begin
        $fatal(
          1,
          "[FAIL] %s SLAVE counters/frame mismatch slave_frame=%0d spi_frame=%0d compare/swap/total=%0d/%0d/%0d",
          iContext,
          uSlave.uSortSlaveRegs.oLastFrameId,
          lastSpiFrameId,
          uSlave.uSortSlaveRegs.oCompareCnt,
          uSlave.uSortSlaveRegs.oSwapCnt,
          uSlave.uSortSlaveRegs.oTotalCnt
        );
      end

      if (uSlave.uSortSlaveRegs.oErrCode != 16'd0) begin
        $fatal(1, "[FAIL] %s SLAVE error_code=0x%04x", iContext, uSlave.uSortSlaveRegs.oErrCode);
      end
      if (dut.uAPB_FND.uFndRegs.oDigitsBcd != iExpectedFndDigits) begin
        $fatal(
          1,
          "[FAIL] %s MASTER FND final digits expected=0x%04x got=0x%04x",
          iContext,
          iExpectedFndDigits,
          dut.uAPB_FND.uFndRegs.oDigitsBcd
        );
      end
      if (!i2cAddrMatchedSeen || !i2cSlaveIdReadSeen || !i2cBrightnessWriteSeen || !i2cDisplayModeWriteSeen) begin
        $fatal(1, "[FAIL] %s missing I2C init/runtime activity", iContext);
      end
      if (i2cDisplayModeWriteCount <= iDisplayModeBase) begin
        $fatal(1, "[FAIL] %s missing runtime DISPLAY_MODE writes", iContext);
      end
      if (fndChangeCount < 2) begin
        $fatal(1, "[FAIL] %s MASTER FND did not show enough activity changes=%0d", iContext, fndChangeCount);
      end
      if (slaveSelectedChangeCount == 0) begin
        $fatal(1, "[FAIL] %s SLAVE selected FND counter did not change", iContext);
      end
      CheckBusPathCoverage(iContext);

      $display("[PASS] %s", iContext);
    end
  endtask

  task automatic CheckBusPeriphHit(
    input string       iContext,
    input int unsigned iPeriphIdx,
    input bit          iNeedRead,
    input bit          iNeedWrite
  );
    begin
      if (iNeedRead && (apbReadCompleteCount[iPeriphIdx] == 0)) begin
        $fatal(1, "[FAIL] %s missing APB read hit for %s through AXI bridge", iContext, BusPeriphName(iPeriphIdx));
      end
      if (iNeedWrite && (apbWriteCompleteCount[iPeriphIdx] == 0)) begin
        $fatal(1, "[FAIL] %s missing APB write hit for %s through AXI bridge", iContext, BusPeriphName(iPeriphIdx));
      end
    end
  endtask

  task automatic CheckBusPathCoverage(input string iContext);
    begin
      if ((nativeApbReqCount == 0) || (nativeApbReadReqCount == 0) || (nativeApbWriteReqCount == 0)) begin
        $fatal(
          1,
          "[FAIL] %s native APB-window requests missing total/read/write=%0d/%0d/%0d",
          iContext,
          nativeApbReqCount,
          nativeApbReadReqCount,
          nativeApbWriteReqCount
        );
      end
      if ((axiReadTxnCount == 0) || (axiWriteTxnCount == 0)) begin
        $fatal(1, "[FAIL] %s AXI transactions missing read/write=%0d/%0d", iContext, axiReadTxnCount, axiWriteTxnCount);
      end
      if (axiErrorRespCount != 0) begin
        $fatal(1, "[FAIL] %s AXI error responses observed=%0d", iContext, axiErrorRespCount);
      end

      CheckBusPeriphHit(iContext, LP_BUS_PERIPH_UART, 1'b1, 1'b1);
      CheckBusPeriphHit(iContext, LP_BUS_PERIPH_GPIO, 1'b1, 1'b1);
      CheckBusPeriphHit(iContext, LP_BUS_PERIPH_I2C,  1'b1, 1'b1);
      CheckBusPeriphHit(iContext, LP_BUS_PERIPH_INTC, 1'b1, 1'b1);
      CheckBusPeriphHit(iContext, LP_BUS_PERIPH_SPI,  1'b1, 1'b1);
      CheckBusPeriphHit(iContext, LP_BUS_PERIPH_FND,  1'b0, 1'b1);
      CheckBusPeriphHit(iContext, LP_BUS_PERIPH_TIMER, 1'b1, 1'b1);

      $display(
        "[INFO] %s AXI/APB path covered native=%0d axi_rd/wr=%0d/%0d apb_complete=%0d UART r/w=%0d/%0d GPIO r/w=%0d/%0d I2C r/w=%0d/%0d INTC r/w=%0d/%0d SPI r/w=%0d/%0d FND r/w=%0d/%0d TIMER r/w=%0d/%0d",
        iContext,
        nativeApbReqCount,
        axiReadTxnCount,
        axiWriteTxnCount,
        apbCompleteCount,
        apbReadCompleteCount[LP_BUS_PERIPH_UART],
        apbWriteCompleteCount[LP_BUS_PERIPH_UART],
        apbReadCompleteCount[LP_BUS_PERIPH_GPIO],
        apbWriteCompleteCount[LP_BUS_PERIPH_GPIO],
        apbReadCompleteCount[LP_BUS_PERIPH_I2C],
        apbWriteCompleteCount[LP_BUS_PERIPH_I2C],
        apbReadCompleteCount[LP_BUS_PERIPH_INTC],
        apbWriteCompleteCount[LP_BUS_PERIPH_INTC],
        apbReadCompleteCount[LP_BUS_PERIPH_SPI],
        apbWriteCompleteCount[LP_BUS_PERIPH_SPI],
        apbReadCompleteCount[LP_BUS_PERIPH_FND],
        apbWriteCompleteCount[LP_BUS_PERIPH_FND],
        apbReadCompleteCount[LP_BUS_PERIPH_TIMER],
        apbWriteCompleteCount[LP_BUS_PERIPH_TIMER]
      );
    end
  endtask

  task automatic RunCaseA;
    int unsigned displayModeBase;
    begin
      ResetDuts();
      WaitForFirmwareReady("Case A UART load/sort");
      displayModeBase = i2cDisplayModeWriteCount;
      WaitForMasterFnd(16'h0000, LP_CASE_TIMEOUT_CYCLES, "Case A reset FND");
      UartSendByte(8'h31);
      WaitForMasterFnd(16'h0001, LP_CASE_TIMEOUT_CYCLES, "Case A FND after 1");
      UartSendByte(8'h32);
      WaitForMasterFnd(16'h0012, LP_CASE_TIMEOUT_CYCLES, "Case A FND after 12");
      UartSendByte(8'h35);
      WaitForMasterFnd(16'h0125, LP_CASE_TIMEOUT_CYCLES, "Case A FND after 125");
      UartSendByte(8'h33);
      WaitForMasterFnd(16'h1253, LP_CASE_TIMEOUT_CYCLES, "Case A FND after 1253");
      UartSendByte(8'h73);
      CheckFinalState("Case A UART load/sort", "01 02 03 05", 6, 1, 7, 16'h1235, displayModeBase);
    end
  endtask

  task automatic RunCaseB;
    int unsigned displayModeBase;
    begin
      ResetDuts();
      WaitForFirmwareReady("Case B GPIO start");
      displayModeBase = i2cDisplayModeWriteCount;
      UartSendString("21");
      WaitForMasterFnd(16'h0021, LP_CASE_TIMEOUT_CYCLES, "Case B FND before start");
      GpioPulse(0);
      WaitForSortState("Case B GPIO start");
      CheckFinalState("Case B GPIO start", "00 00 01 02", 6, 1, 7, 16'h0012, displayModeBase);
    end
  endtask

  task automatic RunCaseC;
    int unsigned displayModeBase;
    int unsigned activityBeforeQuiet;
    int unsigned activityAfterStep;
    begin
      ResetDuts();
      WaitForFirmwareReady("Case C GPIO pause/step/resume");
      displayModeBase = i2cDisplayModeWriteCount;
      UartSendString("421sp");
      WaitForSpiPaused("Case C GPIO pause/step/resume");

      activityBeforeQuiet = spiCompareFrameCount + spiSwapFrameCount + spiPassDoneFrameCount + spiDoneFrameCount;
      WaitCycles(2_000);
      if ((spiCompareFrameCount + spiSwapFrameCount + spiPassDoneFrameCount + spiDoneFrameCount) != activityBeforeQuiet) begin
        $fatal(1, "[FAIL] Case C emitted free-running frames while paused");
      end

      GpioPulse(2);
      WaitCycles(10_000);
      activityAfterStep = spiCompareFrameCount + spiSwapFrameCount + spiPassDoneFrameCount + spiDoneFrameCount;
      if (activityAfterStep <= activityBeforeQuiet) begin
        $fatal(1, "[FAIL] Case C GPIO step did not advance sorting once");
      end
      WaitCycles(2_000);
      if ((spiCompareFrameCount + spiSwapFrameCount + spiPassDoneFrameCount + spiDoneFrameCount) != activityAfterStep) begin
        $fatal(1, "[FAIL] Case C emitted more than the requested single step while paused");
      end

      GpioPulse(1);
      CheckFinalState("Case C GPIO pause/step/resume", "00 01 02 04", 6, 3, 9, 16'h0124, displayModeBase);
    end
  endtask

  task automatic RunCaseD;
    int unsigned displayModeBase;
    begin
      ResetDuts();
      WaitForFirmwareReady("Case D GPIO reset");
      displayModeBase = i2cDisplayModeWriteCount;
      UartSendString("91");
      WaitForMasterFnd(16'h0091, LP_CASE_TIMEOUT_CYCLES, "Case D FND before reset");
      GpioPulse(3);
      WaitCycles(5_000);
      if (dut.uAPB_FND.uFndRegs.oDigitsBcd != 16'd0) begin
        $fatal(1, "[FAIL] Case D MASTER FND did not return to idle after GPIO reset");
      end
      ResetSpiScoreboard();
      UartSendString("90s");
      CheckFinalState("Case D GPIO reset", "00 00 00 09", 6, 1, 7, 16'h0009, displayModeBase);
    end
  endtask

  task automatic RunCaseE;
    int unsigned displayModeBase;
    begin
      ResetDuts();
      WaitForFirmwareReady("Case E I2C display mode");
      displayModeBase = i2cDisplayModeWriteCount;
      UartSendString("321s");
      CheckFinalState("Case E I2C display mode", "00 01 02 03", 6, 3, 9, 16'h0123, displayModeBase);
      if (uSlave.uSortSlaveRegs.oDisplayMode != 8'd3) begin
        $fatal(1, "[FAIL] Case E SLAVE display mode final expected=3 got=%0d", uSlave.uSortSlaveRegs.oDisplayMode);
      end
    end
  endtask

  initial begin : run_test
    iRst   = 1'b1;
    iUartRx = 1'b1;
    iGpioIn = '0;
    ResetScoreboard();

    RunCaseA();
    RunCaseB();
    RunCaseC();
    RunCaseD();
    RunCaseE();

    $display("[PASS] Bubble Sort final E2E XSIM completed");
    $finish;
  end

endmodule
