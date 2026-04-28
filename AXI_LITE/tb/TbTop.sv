`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: TbTop
Role: Simple integrated functional verification for AXI_MASTER and AXI_SLAVE
Summary:
  - Connects AXI_MASTER and AXI_SLAVE end-to-end
  - Verifies reset, full-register write/read, overwrite, and response status
  - Covers all four slave registers through the master local interface
[MODULE_INFO_END]
*/

module TbTop;

  localparam int         LP_CLK_HALF_PERIOD = 5;
  localparam int         LP_TIMEOUT_CYCLES  = 64;
  localparam int         LP_REG_COUNT       = 4;
  localparam logic [1:0] LP_AXI_RESP_OKAY   = 2'b00;

  localparam logic [31:0] LP_REG_ADDR [0:LP_REG_COUNT-1] = '{
    32'h0000_0000,
    32'h0000_0004,
    32'h0000_0008,
    32'h0000_000C
  };

  localparam logic [31:0] LP_INIT_DATA [0:LP_REG_COUNT-1] = '{
    32'h1111_2222,
    32'h3333_4444,
    32'h5555_6666,
    32'h7777_8888
  };

  int tbPassCnt = 0;
  int tbFailCnt = 0;

  logic        tb_iClk;
  logic        tb_iRstn;
  logic        tb_iTransfer;
  logic        tb_oReady;
  logic [31:0] tb_iAddr;
  logic [31:0] tb_iWData;
  logic        tb_iWrite;
  logic [31:0] tb_oRData;
  logic [1:0]  tb_oWriteResp;
  logic        tb_oWriteRespValid;
  logic [1:0]  tb_oReadResp;
  logic        tb_oReadRespValid;

  logic [31:0] wMaster2Slave_AwAddr;
  logic        wMaster2Slave_AwValid;
  logic        wSlave2Master_AwReady;
  logic [31:0] wMaster2Slave_WData;
  logic [3:0]  wMaster2Slave_WStrb;
  logic        wMaster2Slave_WValid;
  logic        wSlave2Master_WReady;
  logic [1:0]  wSlave2Master_BResp;
  logic        wSlave2Master_BValid;
  logic        wMaster2Slave_BReady;
  logic [31:0] wMaster2Slave_ArAddr;
  logic        wMaster2Slave_ArValid;
  logic        wSlave2Master_ArReady;
  logic [31:0] wSlave2Master_RData;
  logic [1:0]  wSlave2Master_RResp;
  logic        wSlave2Master_RValid;
  logic        wMaster2Slave_RReady;

  logic [31:0] tbExpectedData [0:LP_REG_COUNT-1];

  AXI_MASTER uAxiMaster (
    .iClk           (tb_iClk),
    .iRstn          (tb_iRstn),
    .iTransfer      (tb_iTransfer),
    .oReady         (tb_oReady),
    .iAddr          (tb_iAddr),
    .iWData         (tb_iWData),
    .iWrite         (tb_iWrite),
    .oRData         (tb_oRData),
    .oWriteResp     (tb_oWriteResp),
    .oWriteRespValid(tb_oWriteRespValid),
    .oReadResp      (tb_oReadResp),
    .oReadRespValid (tb_oReadRespValid),
    .oMAwAddr       (wMaster2Slave_AwAddr),
    .oMAwValid      (wMaster2Slave_AwValid),
    .iMAwReady      (wSlave2Master_AwReady),
    .oMWData        (wMaster2Slave_WData),
    .oMWStrb        (wMaster2Slave_WStrb),
    .oMWValid       (wMaster2Slave_WValid),
    .iMWReady       (wSlave2Master_WReady),
    .iMBResp        (wSlave2Master_BResp),
    .iMBValid       (wSlave2Master_BValid),
    .oMBReady       (wMaster2Slave_BReady),
    .oMArAddr       (wMaster2Slave_ArAddr),
    .oMArValid      (wMaster2Slave_ArValid),
    .iMArReady      (wSlave2Master_ArReady),
    .iMRData        (wSlave2Master_RData),
    .iMRResp        (wSlave2Master_RResp),
    .iMRValid       (wSlave2Master_RValid),
    .oMRReady       (wMaster2Slave_RReady)
  );

  AXI_SLAVE uAxiSlave (
    .iClk     (tb_iClk),
    .iRstn    (tb_iRstn),
    .iSAwAddr (wMaster2Slave_AwAddr),
    .iSAwValid(wMaster2Slave_AwValid),
    .oSAwReady(wSlave2Master_AwReady),
    .iSWData  (wMaster2Slave_WData),
    .iSWStrb  (wMaster2Slave_WStrb),
    .iSWValid (wMaster2Slave_WValid),
    .oSWReady (wSlave2Master_WReady),
    .oSBResp  (wSlave2Master_BResp),
    .oSBValid (wSlave2Master_BValid),
    .iSBReady (wMaster2Slave_BReady),
    .iSArAddr (wMaster2Slave_ArAddr),
    .iSArValid(wMaster2Slave_ArValid),
    .oSArReady(wSlave2Master_ArReady),
    .oSRData  (wSlave2Master_RData),
    .oSRResp  (wSlave2Master_RResp),
    .oSRValid (wSlave2Master_RValid),
    .iSRReady (wMaster2Slave_RReady)
  );

  // Clock generation
  initial begin
    tb_iClk = 1'b0;
    forever #(LP_CLK_HALF_PERIOD) tb_iClk = ~tb_iClk;
  end

  // Waveform dump
  initial begin
    $dumpfile("tb_axi_integrated.vcd");
    $dumpvars(0, TbTop);
  end

  // Watchdog
  initial begin
    #(LP_TIMEOUT_CYCLES * 100);
    $fatal(1, "[TB] Watchdog timeout");
  end

  task automatic Fail(
    input string iMsg
  );
    begin
      tbFailCnt += 1;
      $error("[TB] %s", iMsg);
    end
  endtask

  task automatic DriveIdleSignals;
    begin
      tb_iTransfer = 1'b0;
      tb_iAddr     = '0;
      tb_iWData    = '0;
      tb_iWrite    = 1'b0;
    end
  endtask

  task automatic InitExpectedData;
    begin
      for (int regIdx = 0; regIdx < LP_REG_COUNT; regIdx += 1) begin
        tbExpectedData[regIdx] = '0;
      end
    end
  endtask

  task automatic ApplyReset;
    begin
      DriveIdleSignals();
      tb_iRstn = 1'b0;
      repeat (4) @(posedge tb_iClk);
      tb_iRstn = 1'b1;
      repeat (2) @(posedge tb_iClk);
    end
  endtask

  task automatic WaitForMasterReady(
    input string iPhase
  );
    int timeoutCycles;
    begin
      timeoutCycles = 0;
      while (!tb_oReady && (timeoutCycles < LP_TIMEOUT_CYCLES)) begin
        @(posedge tb_iClk);
        timeoutCycles += 1;
      end

      if (!tb_oReady) begin
        Fail($sformatf("%s: master did not return to ready", iPhase));
      end
    end
  endtask

  task automatic StartTransfer(
    input logic [31:0] iAddr,
    input logic [31:0] iData,
    input logic        iWriteMode
  );
    begin
      @(negedge tb_iClk);
      tb_iAddr     = iAddr;
      tb_iWData    = iData;
      tb_iWrite    = iWriteMode;
      tb_iTransfer = 1'b1;

      @(posedge tb_iClk);

      @(negedge tb_iClk);
      DriveIdleSignals();
    end
  endtask

  task automatic CheckResetState;
    begin
      if (!tb_oReady) begin
        Fail("reset check failed: master did not return to ready state");
      end

      if (tb_oWriteRespValid || tb_oReadRespValid) begin
        Fail("reset check failed: response valid outputs were not cleared");
      end

      if (wMaster2Slave_AwValid || wMaster2Slave_WValid || wMaster2Slave_ArValid ||
          wMaster2Slave_BReady || wMaster2Slave_RReady) begin
        Fail("reset check failed: AXI master outputs were not idle");
      end

      if (tbFailCnt == 0) begin
        tbPassCnt += 1;
        $display("[TB] Reset check passed");
      end
    end
  endtask

  task automatic IssueWriteByIndex(
    input int          iIdx,
    input logic [31:0] iData
  );
    int failCntStart;
    int timeoutCycles;
    begin
      failCntStart = tbFailCnt;
      WaitForMasterReady($sformatf("write reg%0d start", iIdx));
      if (tbFailCnt != failCntStart) begin
        return;
      end

      StartTransfer(LP_REG_ADDR[iIdx], iData, 1'b1);

      timeoutCycles = 0;
      while (!(wMaster2Slave_AwValid && wMaster2Slave_WValid) &&
             (timeoutCycles < LP_TIMEOUT_CYCLES)) begin
        @(posedge tb_iClk);
        timeoutCycles += 1;
      end

      if (!(wMaster2Slave_AwValid && wMaster2Slave_WValid)) begin
        Fail($sformatf("write reg%0d failed: AXI write valids did not assert", iIdx));
        return;
      end

      if ((wMaster2Slave_AwAddr !== LP_REG_ADDR[iIdx]) ||
          (wMaster2Slave_WData  !== iData) ||
          (wMaster2Slave_WStrb  !== 4'hF)) begin
        Fail($sformatf("write reg%0d failed: AXI payload mismatch", iIdx));
        return;
      end

      WaitForMasterReady($sformatf("write reg%0d completion", iIdx));
      if (tbFailCnt != failCntStart) begin
        return;
      end

      if (!tb_oWriteRespValid || (tb_oWriteResp !== LP_AXI_RESP_OKAY)) begin
        Fail($sformatf("write reg%0d failed: local BRESP was not OKAY", iIdx));
        return;
      end

      tbExpectedData[iIdx] = iData;
      $display("[TB] Write passed: addr=%h data=%h", LP_REG_ADDR[iIdx], iData);
    end
  endtask

  task automatic IssueReadByIndex(
    input int iIdx
  );
    int failCntStart;
    int timeoutCycles;
    begin
      failCntStart = tbFailCnt;
      WaitForMasterReady($sformatf("read reg%0d start", iIdx));
      if (tbFailCnt != failCntStart) begin
        return;
      end

      StartTransfer(LP_REG_ADDR[iIdx], '0, 1'b0);

      timeoutCycles = 0;
      while (!wMaster2Slave_ArValid && (timeoutCycles < LP_TIMEOUT_CYCLES)) begin
        @(posedge tb_iClk);
        timeoutCycles += 1;
      end

      if (!wMaster2Slave_ArValid) begin
        Fail($sformatf("read reg%0d failed: ARVALID did not assert", iIdx));
        return;
      end

      if (wMaster2Slave_ArAddr !== LP_REG_ADDR[iIdx]) begin
        Fail($sformatf("read reg%0d failed: ARADDR mismatch", iIdx));
        return;
      end

      WaitForMasterReady($sformatf("read reg%0d completion", iIdx));
      if (tbFailCnt != failCntStart) begin
        return;
      end

      if (!tb_oReadRespValid || (tb_oReadResp !== LP_AXI_RESP_OKAY)) begin
        Fail($sformatf("read reg%0d failed: local RRESP was not OKAY", iIdx));
        return;
      end

      if (tb_oRData !== tbExpectedData[iIdx]) begin
        Fail($sformatf("read reg%0d failed: readback %h expected %h",
                       iIdx, tb_oRData, tbExpectedData[iIdx]));
        return;
      end

      $display("[TB] Read passed: addr=%h data=%h", LP_REG_ADDR[iIdx], tb_oRData);
    end
  endtask

  task automatic RunResetReadSequence;
    begin
      $display("[TB] Reset-value readback sequence start");
      for (int regIdx = 0; regIdx < LP_REG_COUNT; regIdx += 1) begin
        IssueReadByIndex(regIdx);
      end

      if (tbFailCnt == 0) begin
        tbPassCnt += 1;
        $display("[TB] Reset-value readback sequence passed");
      end
    end
  endtask

  task automatic RunProgramAndOverwriteSequence;
    begin
      $display("[TB] Program and overwrite sequence start");

      for (int regIdx = 0; regIdx < LP_REG_COUNT; regIdx += 1) begin
        IssueWriteByIndex(regIdx, LP_INIT_DATA[regIdx]);
      end

      for (int regIdx = 0; regIdx < LP_REG_COUNT; regIdx += 1) begin
        IssueReadByIndex(regIdx);
      end

      IssueWriteByIndex(2, 32'hA5A5_5A5A);
      IssueWriteByIndex(1, 32'hCAFE_BABE);

      for (int regIdx = 0; regIdx < LP_REG_COUNT; regIdx += 1) begin
        IssueReadByIndex(regIdx);
      end

      if (tbFailCnt == 0) begin
        tbPassCnt += 1;
        $display("[TB] Program and overwrite sequence passed");
      end
    end
  endtask

  initial begin
    DriveIdleSignals();
    InitExpectedData();
    tb_iRstn = 1'b0;

    ApplyReset();
    CheckResetState();
    RunResetReadSequence();
    RunProgramAndOverwriteSequence();

    $display("[TB] Verification summary: %0d passed, %0d failed", tbPassCnt, tbFailCnt);

    if (tbFailCnt != 0) begin
      $fatal(1, "[TB] Integrated verification failed");
    end

    $display("[TB] Integrated verification completed successfully");
    #20;
    $finish;
  end

endmodule
