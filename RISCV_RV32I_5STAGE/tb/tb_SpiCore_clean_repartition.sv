/*
[MODULE_INFO_START]
Name: tb_SpiCore_clean_repartition
Role: Focused SPI core regression for the clean repartition refactor
Summary:
  - Checks valid 24-byte mode0 frame sequencing, RX push count, and DONE pulse
  - Checks invalid mode, busy START drop, TX underflow, and reset cleanup behavior
  - Exercises only the SpiCore APB-facing contract so register-map behavior stays out of scope
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module tb_SpiCore_clean_repartition;

  logic        iClk;
  logic        iRst;
  logic        iEn;
  logic        iStartPulse;
  logic        iCpol;
  logic        iCpha;
  logic        iLsbFirst;
  logic [7:0]  iFrameLen;
  logic [15:0] iClkDiv;
  logic [7:0]  iCsCtrl;
  logic [7:0]  iTxFifoData;
  logic        iTxFifoValid;
  logic        iMiso;
  logic        oBusy;
  logic        oDonePulse;
  logic        oTxFifoPopPulse;
  logic [7:0]  oRxFifoPushData;
  logic        oRxFifoPushPulse;
  logic        oTxUnderflowPulse;
  logic        oModeErrPulse;
  logic        oFrameDroppedPulse;
  logic        oSclk;
  logic        oMosi;
  logic        oCsN;

  int unsigned doneCount;
  int unsigned txPopCount;
  int unsigned rxPushCount;
  int unsigned underflowCount;
  int unsigned modeErrorCount;
  int unsigned frameDroppedCount;
  int unsigned sclkRiseCount;

  SpiCore uDut (
    .iClk               (iClk),
    .iRst              (iRst),
    .iEn            (iEn),
    .iStartPulse        (iStartPulse),
    .iCpol              (iCpol),
    .iCpha              (iCpha),
    .iLsbFirst          (iLsbFirst),
    .iFrameLen          (iFrameLen),
    .iClkDiv            (iClkDiv),
    .iCsCtrl            (iCsCtrl),
    .iTxFifoData        (iTxFifoData),
    .iTxFifoValid       (iTxFifoValid),
    .iMiso              (iMiso),
    .oBusy              (oBusy),
    .oDonePulse         (oDonePulse),
    .oTxFifoPopPulse    (oTxFifoPopPulse),
    .oRxFifoPushData    (oRxFifoPushData),
    .oRxFifoPushPulse   (oRxFifoPushPulse),
    .oTxUnderflowPulse  (oTxUnderflowPulse),
    .oModeErrPulse    (oModeErrPulse),
    .oFrameDroppedPulse (oFrameDroppedPulse),
    .oSclk              (oSclk),
    .oMosi              (oMosi),
    .oCsN               (oCsN)
  );

  initial begin
    iClk = 1'b0;
    forever #5 iClk = ~iClk;
  end

  initial begin
    #2_000_000;
    $fatal(1, "SPI focused TB watchdog expired");
  end

  always @(posedge iClk) begin
    #1;
    if (!iRst) begin
      if (oDonePulse) begin
        doneCount++;
      end

      if (oTxFifoPopPulse) begin
        txPopCount++;
      end

      if (oRxFifoPushPulse) begin
        rxPushCount++;
      end

      if (oTxUnderflowPulse) begin
        underflowCount++;
      end

      if (oModeErrPulse) begin
        modeErrorCount++;
      end

      if (oFrameDroppedPulse) begin
        frameDroppedCount++;
      end

    end
  end

  always @(posedge oSclk) begin
    if (!oCsN) begin
      sclkRiseCount++;
    end
  end

  task automatic ClearCounters();
    begin
      doneCount         = 0;
      txPopCount        = 0;
      rxPushCount       = 0;
      underflowCount    = 0;
      modeErrorCount    = 0;
      frameDroppedCount = 0;
      sclkRiseCount     = 0;
    end
  endtask

  task automatic ApplyReset();
    begin
      iRst        = 1'b1;
      iStartPulse = 1'b0;
      repeat (4) @(posedge iClk);
      #1;
      iRst = 1'b0;
      repeat (2) @(posedge iClk);
      #1;
      ClearCounters();
    end
  endtask

  task automatic PulseStart();
    begin
      @(negedge iClk);
      iStartPulse = 1'b1;
      @(negedge iClk);
      iStartPulse = 1'b0;
    end
  endtask

  task automatic WaitCycles(input int unsigned cycleCount);
    begin
      repeat (cycleCount) @(posedge iClk);
      #1;
    end
  endtask

  task automatic WaitDone();
    int unsigned cycles;
    begin
      cycles = 0;
      while ((doneCount == 0) && (cycles < 5000)) begin
        @(posedge iClk);
        #1;
        cycles++;
      end

      if (doneCount == 0) begin
        $fatal(1, "SPI DONE pulse did not arrive");
      end
    end
  endtask

  task automatic WaitBusy();
    int unsigned cycles;
    begin
      cycles = 0;
      while (!oBusy && (cycles < 100)) begin
        @(posedge iClk);
        #1;
        cycles++;
      end

      if (!oBusy) begin
        $fatal(1, "SPI core did not enter busy state");
      end
    end
  endtask

  task automatic WaitIdle();
    int unsigned cycles;
    begin
      cycles = 0;
      while (oBusy && (cycles < 5000)) begin
        @(posedge iClk);
        #1;
        cycles++;
      end

      if (oBusy) begin
        $fatal(1, "SPI core did not return idle");
      end

      repeat (2) @(posedge iClk);
      #1;
    end
  endtask

  initial begin
    iEn      = 1'b1;
    iStartPulse  = 1'b0;
    iCpol        = 1'b0;
    iCpha        = 1'b0;
    iLsbFirst    = 1'b0;
    iFrameLen    = 8'd24;
    iClkDiv      = 16'd0;
    iCsCtrl      = 8'h01;
    iTxFifoData  = 8'hA5;
    iTxFifoValid = 1'b1;
    iMiso        = 1'b0;

    ApplyReset();

    PulseStart();
    WaitDone();
    if (txPopCount != 24) begin
      $fatal(1, "SPI valid frame pop count mismatch: %0d", txPopCount);
    end
    if (rxPushCount != 24) begin
      $fatal(1, "SPI valid frame RX push count mismatch: %0d", rxPushCount);
    end
    if (sclkRiseCount != 192) begin
      $fatal(1, "SPI valid frame SCLK rise count mismatch: %0d", sclkRiseCount);
    end
    if (!oCsN || (underflowCount != 0) || (modeErrorCount != 0) || (frameDroppedCount != 0)) begin
      $fatal(1, "SPI valid frame side effects mismatch: csN=%0b underflow=%0d modeErr=%0d dropped=%0d",
             oCsN, underflowCount, modeErrorCount, frameDroppedCount);
    end

    ClearCounters();
    iCpha = 1'b1;
    PulseStart();
    WaitCycles(6);
    if ((modeErrorCount != 1) || (doneCount != 0) || oBusy) begin
      $fatal(1, "SPI invalid mode did not produce only a mode-error pulse");
    end
    iCpha = 1'b0;

    ClearCounters();
    PulseStart();
    WaitBusy();
    PulseStart();
    WaitDone();
    if (frameDroppedCount != 1) begin
      $fatal(1, "SPI busy START did not produce one dropped-frame pulse");
    end

    ClearCounters();
    iTxFifoValid = 1'b0;
    PulseStart();
    WaitIdle();
    if ((underflowCount != 1) || (doneCount != 0) || !oCsN) begin
      $fatal(1, "SPI underflow behavior mismatch");
    end
    iTxFifoValid = 1'b1;

    ClearCounters();
    PulseStart();
    WaitBusy();
    iRst = 1'b1;
    WaitCycles(3);
    if (oBusy || !oCsN || oSclk || oMosi) begin
      $fatal(1, "SPI reset cleanup behavior mismatch");
    end
    iRst = 1'b0;
    WaitCycles(3);

    $display("tb_SpiCore_clean_repartition PASS");
    $finish;
  end

endmodule
