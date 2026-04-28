`timescale 1ns / 1ps

/*
[MODULE_INFO_START]
Name: TbAxiLiteProtocol
Role: Compact AXI_SLAVE protocol verification
Summary:
  - Verifies reset defaults, byte strobes, and split-channel operation
  - Confirms pending B/R responses block new AW/AR acceptance
  - Checks held-WVALID does not trigger a second write
[MODULE_INFO_END]
*/

module TbAxiLiteProtocol;

  localparam int         LP_CLK_HALF_PERIOD = 5;
  localparam int         LP_TIMEOUT_CYCLES  = 64;
  localparam logic [1:0] LP_AXI_RESP_OKAY   = 2'b00;
  localparam logic [31:0] LP_ADDR_REG0      = 32'h0000_0000;
  localparam logic [31:0] LP_ADDR_REG1      = 32'h0000_0004;
  localparam logic [31:0] LP_ADDR_REG2      = 32'h0000_0008;

  int tbPassCnt = 0;
  int tbFailCnt = 0;

  logic        tb_iClk;
  logic        tb_iRstn;
  logic [31:0] tb_iSAwAddr;
  logic        tb_iSAwValid;
  logic        tb_oSAwReady;
  logic [31:0] tb_iSWData;
  logic [3:0]  tb_iSWStrb;
  logic        tb_iSWValid;
  logic        tb_oSWReady;
  logic [1:0]  tb_oSBResp;
  logic        tb_oSBValid;
  logic        tb_iSBReady;
  logic [31:0] tb_iSArAddr;
  logic        tb_iSArValid;
  logic        tb_oSArReady;
  logic [31:0] tb_oSRData;
  logic [1:0]  tb_oSRResp;
  logic        tb_oSRValid;
  logic        tb_iSRReady;

  AXI_SLAVE uAxiSlave (
    .iClk     (tb_iClk),
    .iRstn    (tb_iRstn),
    .iSAwAddr (tb_iSAwAddr),
    .iSAwValid(tb_iSAwValid),
    .oSAwReady(tb_oSAwReady),
    .iSWData  (tb_iSWData),
    .iSWStrb  (tb_iSWStrb),
    .iSWValid (tb_iSWValid),
    .oSWReady (tb_oSWReady),
    .oSBResp  (tb_oSBResp),
    .oSBValid (tb_oSBValid),
    .iSBReady (tb_iSBReady),
    .iSArAddr (tb_iSArAddr),
    .iSArValid(tb_iSArValid),
    .oSArReady(tb_oSArReady),
    .oSRData  (tb_oSRData),
    .oSRResp  (tb_oSRResp),
    .oSRValid (tb_oSRValid),
    .iSRReady (tb_iSRReady)
  );

  // Clock generation
  initial begin
    tb_iClk = 1'b0;
    forever #(LP_CLK_HALF_PERIOD) tb_iClk = ~tb_iClk;
  end

  // Waveform dump
  initial begin
    $dumpfile("tb_axi_slave_protocol.vcd");
    $dumpvars(0, TbAxiLiteProtocol);
  end

  // Watchdog
  initial begin
    #(LP_TIMEOUT_CYCLES * 140);
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
      tb_iSAwAddr  = '0;
      tb_iSAwValid = 1'b0;
      tb_iSWData   = '0;
      tb_iSWStrb   = '0;
      tb_iSWValid  = 1'b0;
      tb_iSBReady  = 1'b0;
      tb_iSArAddr  = '0;
      tb_iSArValid = 1'b0;
      tb_iSRReady  = 1'b0;
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

  task automatic WaitForAwReady;
    int timeoutCycles;
    begin
      timeoutCycles = 0;
      while (!tb_oSAwReady && (timeoutCycles < LP_TIMEOUT_CYCLES)) begin
        @(posedge tb_iClk);
        timeoutCycles += 1;
      end

      if (!tb_oSAwReady) begin
        Fail("AWREADY timeout");
      end
    end
  endtask

  task automatic WaitForWReady;
    int timeoutCycles;
    begin
      timeoutCycles = 0;
      while (!tb_oSWReady && (timeoutCycles < LP_TIMEOUT_CYCLES)) begin
        @(posedge tb_iClk);
        timeoutCycles += 1;
      end

      if (!tb_oSWReady) begin
        Fail("WREADY timeout");
      end
    end
  endtask

  task automatic WaitForBValid;
    int timeoutCycles;
    begin
      timeoutCycles = 0;
      while (!tb_oSBValid && (timeoutCycles < LP_TIMEOUT_CYCLES)) begin
        @(posedge tb_iClk);
        timeoutCycles += 1;
      end

      if (!tb_oSBValid) begin
        Fail("BVALID timeout");
      end
    end
  endtask

  task automatic WaitForArReady;
    int timeoutCycles;
    begin
      timeoutCycles = 0;
      while (!tb_oSArReady && (timeoutCycles < LP_TIMEOUT_CYCLES)) begin
        @(posedge tb_iClk);
        timeoutCycles += 1;
      end

      if (!tb_oSArReady) begin
        Fail("ARREADY timeout");
      end
    end
  endtask

  task automatic WaitForRValid;
    int timeoutCycles;
    begin
      timeoutCycles = 0;
      while (!tb_oSRValid && (timeoutCycles < LP_TIMEOUT_CYCLES)) begin
        @(posedge tb_iClk);
        timeoutCycles += 1;
      end

      if (!tb_oSRValid) begin
        Fail("RVALID timeout");
      end
    end
  endtask

  task automatic AcceptWriteAddress(
    input logic [31:0] iAddr
  );
    begin
      @(negedge tb_iClk);
      tb_iSAwAddr  = iAddr;
      tb_iSAwValid = 1'b1;

      WaitForAwReady();
      if (tbFailCnt != 0) begin
        return;
      end

      @(posedge tb_iClk);

      @(negedge tb_iClk);
      tb_iSAwAddr  = '0;
      tb_iSAwValid = 1'b0;
    end
  endtask

  task automatic AcceptWriteData(
    input logic [31:0] iData,
    input logic [3:0]  iStrb
  );
    begin
      @(negedge tb_iClk);
      tb_iSWData  = iData;
      tb_iSWStrb  = iStrb;
      tb_iSWValid = 1'b1;

      WaitForWReady();
      if (tbFailCnt != 0) begin
        return;
      end

      @(posedge tb_iClk);

      @(negedge tb_iClk);
      tb_iSWData  = '0;
      tb_iSWStrb  = '0;
      tb_iSWValid = 1'b0;
    end
  endtask

  task automatic AcceptWriteResponse;
    begin
      @(negedge tb_iClk);
      tb_iSBReady = 1'b1;

      WaitForBValid();
      if (tbFailCnt != 0) begin
        return;
      end

      @(posedge tb_iClk);

      if (tb_oSBResp !== LP_AXI_RESP_OKAY) begin
        Fail("BRESP was not OKAY");
      end

      @(negedge tb_iClk);
      tb_iSBReady = 1'b0;
    end
  endtask

  task automatic WriteRegister(
    input logic [31:0] iAddr,
    input logic [31:0] iData,
    input logic [3:0]  iStrb
  );
    begin
      AcceptWriteAddress(iAddr);
      if (tbFailCnt != 0) begin
        return;
      end

      AcceptWriteData(iData, iStrb);
      if (tbFailCnt != 0) begin
        return;
      end

      AcceptWriteResponse();
    end
  endtask

  task automatic AcceptReadAddress(
    input logic [31:0] iAddr
  );
    begin
      @(negedge tb_iClk);
      tb_iSArAddr  = iAddr;
      tb_iSArValid = 1'b1;

      WaitForArReady();
      if (tbFailCnt != 0) begin
        return;
      end

      @(posedge tb_iClk);

      @(negedge tb_iClk);
      tb_iSArAddr  = '0;
      tb_iSArValid = 1'b0;
    end
  endtask

  task automatic CompleteRead(
    output logic [31:0] oData
  );
    begin
      @(negedge tb_iClk);
      tb_iSRReady = 1'b1;

      WaitForRValid();
      if (tbFailCnt != 0) begin
        return;
      end

      oData = tb_oSRData;
      @(posedge tb_iClk);

      if (tb_oSRResp !== LP_AXI_RESP_OKAY) begin
        Fail("RRESP was not OKAY");
      end

      @(negedge tb_iClk);
      tb_iSRReady = 1'b0;
    end
  endtask

  task automatic ReadRegister(
    input  logic [31:0] iAddr,
    output logic [31:0] oData
  );
    begin
      AcceptReadAddress(iAddr);
      if (tbFailCnt != 0) begin
        return;
      end

      CompleteRead(oData);
    end
  endtask

  task automatic CheckResetState;
    logic [31:0] readData;
    begin
      if (tb_oSAwReady || tb_oSWReady || tb_oSBValid || tb_oSArReady || tb_oSRValid) begin
        Fail("reset check failed: slave outputs were not idle");
      end

      ReadRegister(LP_ADDR_REG0, readData);
      if (tbFailCnt != 0) begin
        return;
      end

      if (readData !== '0) begin
        Fail($sformatf("reset check failed: register reset value was %h", readData));
        return;
      end

      tbPassCnt += 1;
      $display("[TB] Reset and default-value check passed");
    end
  endtask

  task automatic RunWStrbCheck;
    logic [31:0] readData;
    int          failCntStart;
    begin
      failCntStart = tbFailCnt;
      $display("[TB] Byte-strobe check start");

      ApplyReset();
      WriteRegister(LP_ADDR_REG0, 32'h1122_3344, 4'hF);
      WriteRegister(LP_ADDR_REG0, 32'hAABB_CCDD, 4'b0101);
      ReadRegister(LP_ADDR_REG0, readData);

      if (tbFailCnt != failCntStart) begin
        return;
      end

      if (readData !== 32'h11BB_33DD) begin
        Fail($sformatf("byte-strobe check failed: read %h expected 11BB33DD", readData));
        return;
      end

      tbPassCnt += 1;
      $display("[TB] Byte-strobe check passed");
    end
  endtask

  task automatic RunPendingWriteResponseGuardCheck;
    logic [31:0] readData;
    int          failCntStart;
    begin
      failCntStart = tbFailCnt;
      $display("[TB] Pending-BRESP guard check start");

      ApplyReset();
      AcceptWriteAddress(LP_ADDR_REG0);
      AcceptWriteData(32'h1111_2222, 4'hF);
      WaitForBValid();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      @(negedge tb_iClk);
      tb_iSAwAddr  = LP_ADDR_REG1;
      tb_iSAwValid = 1'b1;

      repeat (3) begin
        @(posedge tb_iClk);
        if (tb_oSAwReady) begin
          Fail("pending-BRESP guard failed: AWREADY re-opened too early");
          return;
        end
      end

      AcceptWriteResponse();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      WaitForAwReady();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      @(posedge tb_iClk);
      @(negedge tb_iClk);
      tb_iSAwAddr  = '0;
      tb_iSAwValid = 1'b0;

      AcceptWriteData(32'h3333_4444, 4'hF);
      AcceptWriteResponse();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      ReadRegister(LP_ADDR_REG0, readData);
      if ((tbFailCnt != failCntStart) || (readData !== 32'h1111_2222)) begin
        Fail("pending-BRESP guard failed: first register contents were corrupted");
        return;
      end

      ReadRegister(LP_ADDR_REG1, readData);
      if ((tbFailCnt != failCntStart) || (readData !== 32'h3333_4444)) begin
        Fail("pending-BRESP guard failed: second write did not complete");
        return;
      end

      tbPassCnt += 1;
      $display("[TB] Pending-BRESP guard check passed");
    end
  endtask

  task automatic RunPendingReadGuardCheck;
    logic [31:0] firstReadData;
    logic [31:0] secondReadData;
    int          failCntStart;
    begin
      failCntStart = tbFailCnt;
      $display("[TB] Pending-RRESP guard check start");

      ApplyReset();
      WriteRegister(LP_ADDR_REG0, 32'hAAAA_0001, 4'hF);
      WriteRegister(LP_ADDR_REG1, 32'hBBBB_0002, 4'hF);
      if (tbFailCnt != failCntStart) begin
        return;
      end

      AcceptReadAddress(LP_ADDR_REG0);
      WaitForRValid();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      @(negedge tb_iClk);
      tb_iSArAddr  = LP_ADDR_REG1;
      tb_iSArValid = 1'b1;

      repeat (3) begin
        @(posedge tb_iClk);
        if (tb_oSArReady) begin
          Fail("pending-RRESP guard failed: ARREADY re-opened too early");
          return;
        end
      end

      CompleteRead(firstReadData);
      if ((tbFailCnt != failCntStart) || (firstReadData !== 32'hAAAA_0001)) begin
        Fail("pending-RRESP guard failed: first read data was incorrect");
        return;
      end

      WaitForArReady();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      @(posedge tb_iClk);
      @(negedge tb_iClk);
      tb_iSArAddr  = '0;
      tb_iSArValid = 1'b0;

      CompleteRead(secondReadData);
      if ((tbFailCnt != failCntStart) || (secondReadData !== 32'hBBBB_0002)) begin
        Fail("pending-RRESP guard failed: second read did not complete");
        return;
      end

      tbPassCnt += 1;
      $display("[TB] Pending-RRESP guard check passed");
    end
  endtask

  task automatic RunHeldWValidGuardCheck;
    logic [31:0] readBackData;
    int          failCntStart;
    begin
      failCntStart = tbFailCnt;
      $display("[TB] Held-WVALID guard check start");

      ApplyReset();
      AcceptWriteAddress(LP_ADDR_REG2);
      if (tbFailCnt != failCntStart) begin
        return;
      end

      @(negedge tb_iClk);
      tb_iSWData  = 32'h1111_2222;
      tb_iSWStrb  = 4'hF;
      tb_iSWValid = 1'b1;

      WaitForWReady();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      @(posedge tb_iClk);

      @(negedge tb_iClk);
      tb_iSWData = 32'hAAAA_BBBB;

      WaitForBValid();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      repeat (4) begin
        @(posedge tb_iClk);
        if (tb_oSWReady) begin
          Fail("held-WVALID guard failed: WREADY re-opened while BRESP was pending");
          return;
        end
      end

      @(negedge tb_iClk);
      tb_iSWData  = '0;
      tb_iSWStrb  = '0;
      tb_iSWValid = 1'b0;

      AcceptWriteResponse();
      if (tbFailCnt != failCntStart) begin
        return;
      end

      ReadRegister(LP_ADDR_REG2, readBackData);
      if ((tbFailCnt != failCntStart) || (readBackData !== 32'h1111_2222)) begin
        Fail("held-WVALID guard failed: register was overwritten by the second data beat");
        return;
      end

      tbPassCnt += 1;
      $display("[TB] Held-WVALID guard check passed");
    end
  endtask

  initial begin
    DriveIdleSignals();
    tb_iRstn = 1'b0;

    ApplyReset();
    CheckResetState();
    RunWStrbCheck();
    RunPendingWriteResponseGuardCheck();
    RunPendingReadGuardCheck();
    RunHeldWValidGuardCheck();

    $display("[TB] Verification summary: %0d passed, %0d failed", tbPassCnt, tbFailCnt);

    if (tbFailCnt != 0) begin
      $fatal(1, "[TB] Protocol verification failed");
    end

    $display("[TB] Protocol verification completed successfully");
    #20;
    $finish;
  end

endmodule
