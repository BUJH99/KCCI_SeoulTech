/*
[MODULE_INFO_START]
Name: tb_I2cCore_clean_repartition
Role: Focused I2C core regression for the clean repartition refactor
Summary:
  - Checks write/read transaction completion, RX data lane assembly, and TX-ready behavior
  - Checks invalid length, NACK error, and core-reset cleanup behavior
  - Exercises only the I2cCore APB-facing contract with a minimal ACKing open-drain bus model
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module tb_I2cCore_clean_repartition;

  logic        iClk;
  logic        iRst;
  logic        iEn;
  logic        iStartPulse;
  logic        iCoreRstPulse;
  logic        iRw;
  logic [6:0]  iSlaveAddr;
  logic [7:0]  iRegAddr;
  logic [31:0] iWdata;
  logic [2:0]  iLen;
  logic [15:0] iClkDiv;
  logic        iSdaIn;
  logic        oBusy;
  logic        oDonePulse;
  logic        oRxValidPulse;
  logic        oTxReady;
  logic        oAckOk;
  logic [31:0] oRxData;
  logic        oNackPulse;
  logic        oArbLostPulse;
  logic        oBusErrPulse;
  logic        oTimeoutPulse;
  logic        oScl;
  logic        oSclOe;
  logic        oSdaOut;
  logic        oSdaOe;

  logic        ackPhaseActive;
  logic        ackEnable;
  int unsigned doneCount;
  int unsigned rxValidCount;
  int unsigned nackCount;
  int unsigned arbLostCount;
  int unsigned busErrorCount;
  int unsigned timeoutCount;
  int unsigned addrRdLoadCount;
  bit          addrRdLoadOk;

  I2cCore uDut (
    .iClk            (iClk),
    .iRst           (iRst),
    .iEn         (iEn),
    .iStartPulse     (iStartPulse),
    .iCoreRstPulse (iCoreRstPulse),
    .iRw             (iRw),
    .iSlaveAddr      (iSlaveAddr),
    .iRegAddr        (iRegAddr),
    .iWdata          (iWdata),
    .iLen            (iLen),
    .iClkDiv         (iClkDiv),
    .iSdaIn          (iSdaIn),
    .oBusy           (oBusy),
    .oDonePulse      (oDonePulse),
    .oRxValidPulse   (oRxValidPulse),
    .oTxReady        (oTxReady),
    .oAckOk          (oAckOk),
    .oRxData         (oRxData),
    .oNackPulse      (oNackPulse),
    .oArbLostPulse   (oArbLostPulse),
    .oBusErrPulse  (oBusErrPulse),
    .oTimeoutPulse   (oTimeoutPulse),
    .oScl            (oScl),
    .oSclOe          (oSclOe),
    .oSdaOut         (oSdaOut),
    .oSdaOe          (oSdaOe)
  );

  assign ackPhaseActive = ackEnable
                        && ((uDut.uI2cMasterCtrl.state == 5'd7)
                         || (uDut.uI2cMasterCtrl.state == 5'd8)
                         || (uDut.uI2cMasterCtrl.state == 5'd9));

  always_comb begin
    iSdaIn = (oSdaOe || ackPhaseActive) ? 1'b0 : 1'b1;
  end

  initial begin
    iClk = 1'b0;
    forever #5 iClk = ~iClk;
  end

  initial begin
    #2_000_000;
    $fatal(1, "I2C focused TB watchdog expired");
  end

  always @(posedge iClk) begin
    #1;
    if (!iRst) begin
      if (oDonePulse) begin
        doneCount++;
      end

      if (oRxValidPulse) begin
        rxValidCount++;
      end

      if (oNackPulse) begin
        nackCount++;
      end

      if (oArbLostPulse) begin
        arbLostCount++;
      end

      if (oBusErrPulse) begin
        busErrorCount++;
      end

      if (oTimeoutPulse) begin
        timeoutCount++;
      end

    end
  end

  always @(posedge iClk) begin
    if (!iRst && uDut.loadAddrRdPulse) begin
      #1;
      addrRdLoadCount++;
      if (uDut.uI2cMasterDatapath.txByte != {iSlaveAddr, 1'b1}) begin
        addrRdLoadOk = 1'b0;
      end
    end
  end

  task automatic ClearCounters();
    begin
      doneCount     = 0;
      rxValidCount  = 0;
      nackCount     = 0;
      arbLostCount  = 0;
      busErrorCount = 0;
      timeoutCount  = 0;
      addrRdLoadCount = 0;
      addrRdLoadOk    = 1'b1;
    end
  endtask

  task automatic ResetBusModel();
    begin
    end
  endtask

  task automatic ApplyReset();
    begin
      iRst             = 1'b1;
      iStartPulse      = 1'b0;
      iCoreRstPulse  = 1'b0;
      ResetBusModel();
      repeat (4) @(posedge iClk);
      #1;
      iRst = 1'b0;
      repeat (4) @(posedge iClk);
      #1;
      ClearCounters();
      ResetBusModel();
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

  task automatic PulseCoreReset();
    begin
      @(negedge iClk);
      iCoreRstPulse = 1'b1;
      @(negedge iClk);
      iCoreRstPulse = 1'b0;
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
      while ((doneCount == 0) && (cycles < 20000)) begin
        @(posedge iClk);
        #1;
        cycles++;
      end

      if (doneCount == 0) begin
        $fatal(1, "I2C DONE pulse did not arrive: busy=%0b nack=%0d arb=%0d busErr=%0d timeout=%0d",
               oBusy, nackCount, arbLostCount, busErrorCount, timeoutCount);
      end
    end
  endtask

  task automatic WaitBusy();
    int unsigned cycles;
    begin
      cycles = 0;
      while (!oBusy && (cycles < 200)) begin
        @(posedge iClk);
        #1;
        cycles++;
      end

      if (!oBusy) begin
        $fatal(1, "I2C core did not enter busy state");
      end
    end
  endtask

  task automatic WaitIdle();
    int unsigned cycles;
    begin
      cycles = 0;
      while (oBusy && (cycles < 20000)) begin
        @(posedge iClk);
        #1;
        cycles++;
      end

      if (oBusy) begin
        $fatal(1, "I2C core did not return idle");
      end

      repeat (2) @(posedge iClk);
      #1;
    end
  endtask

  task automatic WaitNack();
    int unsigned cycles;
    begin
      cycles = 0;
      while ((nackCount == 0) && (cycles < 20000)) begin
        @(posedge iClk);
        #1;
        cycles++;
      end

      if (nackCount == 0) begin
        $fatal(1, "I2C NACK pulse did not arrive");
      end
    end
  endtask

  initial begin
    iEn        = 1'b1;
    iStartPulse    = 1'b0;
    iCoreRstPulse = 1'b0;
    iRw            = 1'b0;
    iSlaveAddr     = 7'h42;
    iRegAddr       = 8'h10;
    iWdata         = 32'hA4_B3_C2_D1;
    iLen           = 3'd1;
    iClkDiv        = 16'd4;
    ackEnable      = 1'b1;

    ApplyReset();

    iLen = 3'd0;
    PulseStart();
    WaitCycles(8);
    if ((busErrorCount != 1) || (doneCount != 0) || !oTxReady) begin
      $fatal(1, "I2C invalid LEN did not produce only a bus-error pulse");
    end

    ClearCounters();
    ResetBusModel();
    iLen = 3'd1;
    iRw  = 1'b0;
    PulseStart();
    WaitDone();
    if ((doneCount != 1) || (rxValidCount != 0) || !oAckOk || !oTxReady
        || (nackCount != 0) || (arbLostCount != 0) || (busErrorCount != 0) || (timeoutCount != 0)) begin
      $fatal(1, "I2C 1-byte write behavior mismatch");
    end
    ClearCounters();
    ResetBusModel();
    iLen = 3'd4;
    iRw  = 1'b1;
    PulseStart();
    WaitDone();
    if ((doneCount != 1) || (rxValidCount != 1) || !oAckOk || (oRxData != 32'hFFFF_FFFF)) begin
      $fatal(1, "I2C 4-byte read behavior mismatch: rxData=%08h rxValid=%0d", oRxData, rxValidCount);
    end
    if ((addrRdLoadCount != 1) || !addrRdLoadOk) begin
      $fatal(1, "I2C repeated-start read address load mismatch: count=%0d ok=%0d",
             addrRdLoadCount, addrRdLoadOk);
    end

    ClearCounters();
    ResetBusModel();
    ackEnable = 1'b0;
    iLen      = 3'd1;
    iRw       = 1'b0;
    PulseStart();
    WaitNack();
    WaitIdle();
    if ((nackCount != 1) || (doneCount != 0) || oAckOk
        || (arbLostCount != 0) || (busErrorCount != 0) || (timeoutCount != 0)) begin
      $fatal(1, "I2C NACK behavior mismatch");
    end
    ackEnable = 1'b1;

    ClearCounters();
    ResetBusModel();
    iLen = 3'd4;
    iRw  = 1'b0;
    PulseStart();
    WaitBusy();
    PulseCoreReset();
    WaitCycles(8);
    if (oBusy || !oTxReady || oSclOe || oSdaOe) begin
      $fatal(1, "I2C core-reset cleanup behavior mismatch");
    end

    $display("tb_I2cCore_clean_repartition PASS");
    $finish;
  end

endmodule
