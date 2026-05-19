/*
[TB_INFO_START]
Name: tb_DataBusAxiLiteMaster
Target: DataBusAxiLiteMaster
Role: Focused AXI4-Lite master protocol testbench
Scenario:
  - Checks native store/load conversion, independent AW/W acceptance, delayed AXI responses, SLVERR mapping, and active-transaction request isolation
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_DataBusAxiLiteMaster;

  localparam logic [1:0] LP_AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] LP_AXI_RESP_SLVERR = 2'b10;

  logic        iClk;
  logic        iRst;
  logic        iReqValid;
  logic        iReqWr;
  logic [31:0] iReqAddr;
  logic [3:0]  iReqByteEn;
  logic [31:0] iReqWdata;
  logic        iAxiAwready;
  logic        iAxiWready;
  logic        iAxiBvalid;
  logic [1:0]  iAxiBresp;
  logic        iAxiArready;
  logic        iAxiRvalid;
  logic [31:0] iAxiRdata;
  logic [1:0]  iAxiRresp;
  logic        oRspReady;
  logic [31:0] oRspRdata;
  logic        oRspErr;
  logic [31:0] oAxiAwaddr;
  logic [2:0]  oAxiAwprot;
  logic        oAxiAwvalid;
  logic [31:0] oAxiWdata;
  logic [3:0]  oAxiWstrb;
  logic        oAxiWvalid;
  logic        oAxiBready;
  logic [31:0] oAxiAraddr;
  logic [2:0]  oAxiArprot;
  logic        oAxiArvalid;
  logic        oAxiRready;

  DataBusAxiLiteMaster dut (
    .iClk(iClk),
    .iRst(iRst),
    .iReqValid(iReqValid),
    .iReqWr(iReqWr),
    .iReqAddr(iReqAddr),
    .iReqByteEn(iReqByteEn),
    .iReqWdata(iReqWdata),
    .iAxiAwready(iAxiAwready),
    .iAxiWready(iAxiWready),
    .iAxiBvalid(iAxiBvalid),
    .iAxiBresp(iAxiBresp),
    .iAxiArready(iAxiArready),
    .iAxiRvalid(iAxiRvalid),
    .iAxiRdata(iAxiRdata),
    .iAxiRresp(iAxiRresp),
    .oRspReady(oRspReady),
    .oRspRdata(oRspRdata),
    .oRspErr(oRspErr),
    .oAxiAwaddr(oAxiAwaddr),
    .oAxiAwprot(oAxiAwprot),
    .oAxiAwvalid(oAxiAwvalid),
    .oAxiWdata(oAxiWdata),
    .oAxiWstrb(oAxiWstrb),
    .oAxiWvalid(oAxiWvalid),
    .oAxiBready(oAxiBready),
    .oAxiAraddr(oAxiAraddr),
    .oAxiArprot(oAxiArprot),
    .oAxiArvalid(oAxiArvalid),
    .oAxiRready(oAxiRready)
  );

  always #5 iClk = ~iClk;

  task automatic Tick;
    begin
      @(posedge iClk);
      #1;
    end
  endtask

  task automatic CheckEq1(
    input logic  iActual,
    input logic  iExpected,
    input string iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected %0b, got %0b", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq2(
    input logic [1:0] iActual,
    input logic [1:0] iExpected,
    input string      iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected %0b, got %0b", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq3(
    input logic [2:0] iActual,
    input logic [2:0] iExpected,
    input string      iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected %0b, got %0b", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq4(
    input logic [3:0] iActual,
    input logic [3:0] iExpected,
    input string      iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected 0x%0h, got 0x%0h", iContext, iExpected, iActual);
      end
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

  task automatic ResetDut;
    begin
      iRst       = 1'b1;
      iReqValid   = 1'b0;
      iReqWr   = 1'b0;
      iReqAddr    = '0;
      iReqByteEn  = '0;
      iReqWdata   = '0;
      iAxiAwready = 1'b0;
      iAxiWready  = 1'b0;
      iAxiBvalid  = 1'b0;
      iAxiBresp   = LP_AXI_RESP_OKAY;
      iAxiArready = 1'b0;
      iAxiRvalid  = 1'b0;
      iAxiRdata   = '0;
      iAxiRresp   = LP_AXI_RESP_OKAY;
      repeat (3) Tick();
      iRst = 1'b0;
      Tick();
    end
  endtask

  task automatic StartNativeWrite(
    input logic [31:0] iAddr,
    input logic [3:0]  iStrb,
    input logic [31:0] iWdata
  );
    begin
      iReqValid  = 1'b1;
      iReqWr  = 1'b1;
      iReqAddr   = iAddr;
      iReqByteEn = iStrb;
      iReqWdata  = iWdata;
      Tick();
      iReqValid = 1'b0;
      CheckEq1(oAxiAwvalid, 1'b1, "write AWVALID starts");
      CheckEq1(oAxiWvalid, 1'b1, "write WVALID starts");
      CheckEq32(oAxiAwaddr, iAddr, "write AWADDR");
      CheckEq32(oAxiWdata, iWdata, "write WDATA");
      CheckEq4(oAxiWstrb, iStrb, "write WSTRB");
      CheckEq3(oAxiAwprot, 3'b000, "write AWPROT fixed");
    end
  endtask

  task automatic FinishWriteResponse(
    input logic [1:0] iResp,
    input logic       iExpectedErr
  );
    begin
      repeat (2) begin
        Tick();
        CheckEq1(oRspReady, 1'b0, "write response waits for BVALID");
      end

      iAxiBresp  = iResp;
      iAxiBvalid = 1'b1;
      #1;
      CheckEq1(oAxiBready, 1'b1, "write BREADY asserted");
      CheckEq1(oRspReady, 1'b1, "write native response ready");
      CheckEq1(oRspErr, iExpectedErr, "write native response error");
      Tick();
      iAxiBvalid = 1'b0;
    end
  endtask

  task automatic RunWriteAwBeforeW;
    begin
      ResetDut();
      StartNativeWrite(32'h4000_1000, 4'hF, 32'hA5A5_5A5A);

      iAxiAwready = 1'b1;
      Tick();
      iAxiAwready = 1'b0;
      CheckEq1(oAxiAwvalid, 1'b0, "AW accepted before W");
      CheckEq1(oAxiWvalid, 1'b1, "W waits after AW");
      CheckEq32(oAxiAwaddr, 32'h4000_1000, "AWADDR stable after AW wait");

      iAxiWready = 1'b1;
      Tick();
      iAxiWready = 1'b0;
      CheckEq1(oAxiBready, 1'b1, "write waits for response after AW/W");
      FinishWriteResponse(LP_AXI_RESP_OKAY, 1'b0);
    end
  endtask

  task automatic RunWriteWBeforeAwSlverr;
    begin
      ResetDut();
      StartNativeWrite(32'h4000_1004, 4'h3, 32'h0000_BEEF);

      iAxiWready = 1'b1;
      Tick();
      iAxiWready = 1'b0;
      CheckEq1(oAxiWvalid, 1'b0, "W accepted before AW");
      CheckEq1(oAxiAwvalid, 1'b1, "AW waits after W");
      CheckEq32(oAxiWdata, 32'h0000_BEEF, "WDATA stable after W wait");

      iAxiAwready = 1'b1;
      Tick();
      iAxiAwready = 1'b0;
      CheckEq1(oAxiBready, 1'b1, "write waits for SLVERR response");
      FinishWriteResponse(LP_AXI_RESP_SLVERR, 1'b1);
    end
  endtask

  task automatic RunReadOkay;
    begin
      ResetDut();
      iReqValid = 1'b1;
      iReqWr = 1'b0;
      iReqAddr  = 32'h4000_1008;
      Tick();
      iReqValid = 1'b0;
      CheckEq1(oAxiArvalid, 1'b1, "read ARVALID starts");
      CheckEq32(oAxiAraddr, 32'h4000_1008, "read ARADDR");
      CheckEq3(oAxiArprot, 3'b000, "read ARPROT fixed");

      repeat (2) begin
        Tick();
        CheckEq1(oAxiArvalid, 1'b1, "read ARVALID holds while ARREADY low");
        CheckEq1(oRspReady, 1'b0, "read response waits before AR handshake");
      end

      iAxiArready = 1'b1;
      Tick();
      iAxiArready = 1'b0;
      CheckEq1(oAxiRready, 1'b1, "read RREADY asserted");

      repeat (2) begin
        Tick();
        CheckEq1(oRspReady, 1'b0, "read response waits for RVALID");
      end

      iAxiRdata  = 32'h1234_ABCD;
      iAxiRresp  = LP_AXI_RESP_OKAY;
      iAxiRvalid = 1'b1;
      #1;
      CheckEq1(oRspReady, 1'b1, "read native response ready");
      CheckEq32(oRspRdata, 32'h1234_ABCD, "read native response data");
      CheckEq1(oRspErr, 1'b0, "read native response OKAY");
      Tick();
      iAxiRvalid = 1'b0;
    end
  endtask

  task automatic RunReadSlverr;
    begin
      ResetDut();
      iReqValid = 1'b1;
      iReqWr = 1'b0;
      iReqAddr  = 32'h4000_100C;
      Tick();
      iReqValid = 1'b0;
      CheckEq1(oAxiArvalid, 1'b1, "SLVERR read ARVALID starts");

      iAxiArready = 1'b1;
      Tick();
      iAxiArready = 1'b0;
      CheckEq1(oAxiRready, 1'b1, "SLVERR read waits for RVALID");

      iAxiRdata  = 32'hCAFE_F00D;
      iAxiRresp  = LP_AXI_RESP_SLVERR;
      iAxiRvalid = 1'b1;
      #1;
      CheckEq1(oRspReady, 1'b1, "SLVERR read response ready");
      CheckEq32(oRspRdata, 32'hCAFE_F00D, "SLVERR read still returns data");
      CheckEq1(oRspErr, 1'b1, "SLVERR read maps to native error");
      Tick();
      iAxiRvalid = 1'b0;
    end
  endtask

  task automatic RunActiveRequestIsolation;
    begin
      ResetDut();
      StartNativeWrite(32'h4000_1010, 4'hC, 32'hFACE_0001);

      iReqValid  = 1'b1;
      iReqWr  = 1'b0;
      iReqAddr   = 32'h4000_1020;
      iReqByteEn = 4'hF;
      iReqWdata  = 32'h1111_2222;

      repeat (3) begin
        Tick();
        CheckEq1(oAxiArvalid, 1'b0, "active write blocks second read ARVALID");
        CheckEq32(oAxiAwaddr, 32'h4000_1010, "active write keeps original AWADDR");
        CheckEq32(oAxiWdata, 32'hFACE_0001, "active write keeps original WDATA");
      end

      iReqValid   = 1'b0;
      iAxiAwready = 1'b1;
      iAxiWready  = 1'b1;
      Tick();
      iAxiAwready = 1'b0;
      iAxiWready  = 1'b0;
      FinishWriteResponse(LP_AXI_RESP_OKAY, 1'b0);
    end
  endtask

  initial begin
    iClk = 1'b0;
    ResetDut();
    RunWriteAwBeforeW();
    RunWriteWBeforeAwSlverr();
    RunReadOkay();
    RunReadSlverr();
    RunActiveRequestIsolation();
    $display("[PASS] tb_DataBusAxiLiteMaster completed");
    $finish;
  end

  initial begin
    repeat (1000) @(posedge iClk);
    $fatal(1, "[FAIL] tb_DataBusAxiLiteMaster watchdog expired");
  end

endmodule
