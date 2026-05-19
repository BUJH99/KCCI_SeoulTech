/*
[TB_INFO_START]
Name: tb_CsrFile_Timer
Target: CsrFile
Role: Focused CSR MTIE/MTIP hardware pending OR testbench
Scenario:
  - Checks mie.MTIE read/write, mip.MTIP hardware pending reflection, and hardware/software MTIP OR behavior
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_CsrFile_Timer;

  import rv32i_pkg::*;

  logic        iClk;
  logic        iRst;
  logic [11:0] iCsrAddr;
  logic        iCsrWrEn;
  logic [11:0] iCsrWrAddr;
  logic [31:0] iCsrWrData;
  logic        iMretValid;
  logic        iTrapEnterValid;
  logic [31:0] iTrapEnterEpc;
  logic [31:0] iTrapEnterCause;
  logic        iExtIrqPending;
  logic        iTimerIrqPending;
  logic [31:0] oCsrRdata;
  logic [31:0] oMtvec;
  logic [31:0] oMepc;
  logic        oMstatusMie;
  logic        oMstatusMpie;
  logic        oMieMeie;
  logic        oMieMtie;
  logic        oMipMeip;
  logic        oMipMtip;

  CsrFile dut (
    .iClk(iClk),
    .iRst(iRst),
    .iCsrAddr(iCsrAddr),
    .iCsrWrEn(iCsrWrEn),
    .iCsrWrAddr(iCsrWrAddr),
    .iCsrWrData(iCsrWrData),
    .iMretValid(iMretValid),
    .iTrapEnterValid(iTrapEnterValid),
    .iTrapEnterEpc(iTrapEnterEpc),
    .iTrapEnterCause(iTrapEnterCause),
    .iExtIrqPending(iExtIrqPending),
    .iTimerIrqPending(iTimerIrqPending),
    .oCsrRdata(oCsrRdata),
    .oMtvec(oMtvec),
    .oMepc(oMepc),
    .oMstatusMie(oMstatusMie),
    .oMstatusMpie(oMstatusMpie),
    .oMieMeie(oMieMeie),
    .oMieMtie(oMieMtie),
    .oMipMeip(oMipMeip),
    .oMipMtip(oMipMtip)
  );

  always #5 iClk = ~iClk;

  task automatic Tick;
    begin
      @(posedge iClk);
      #1;
    end
  endtask

  task automatic CheckEq1(input logic iActual, input logic iExpected, input string iContext);
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s expected=%0b got=%0b", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq32(input logic [31:0] iActual, input logic [31:0] iExpected, input string iContext);
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s expected=0x%08x got=0x%08x", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CsrWrite(input logic [11:0] iAddr, input logic [31:0] iData);
    begin
      iCsrWrAddr = iAddr;
      iCsrWrData = iData;
      iCsrWrEn   = 1'b1;
      Tick();
      iCsrWrEn   = 1'b0;
      iCsrWrAddr = '0;
      iCsrWrData = '0;
      Tick();
    end
  endtask

  task automatic CsrRead(input logic [11:0] iAddr, output logic [31:0] oData);
    begin
      iCsrAddr = iAddr;
      #1;
      oData = oCsrRdata;
    end
  endtask

  initial begin
    logic [31:0] data;

    iClk              = 1'b0;
    iRst             = 1'b1;
    iCsrAddr          = '0;
    iCsrWrEn       = 1'b0;
    iCsrWrAddr     = '0;
    iCsrWrData     = '0;
    iMretValid        = 1'b0;
    iTrapEnterValid   = 1'b0;
    iTrapEnterEpc     = '0;
    iTrapEnterCause   = '0;
    iExtIrqPending    = 1'b0;
    iTimerIrqPending  = 1'b0;
    repeat (3) Tick();
    iRst = 1'b0;
    Tick();

    CsrWrite(LP_CSR_MIE, 32'h0000_0880);
    CsrRead(LP_CSR_MIE, data);
    CheckEq32(data, 32'h0000_0880, "mie MTIE/MEIE readback");
    CheckEq1(oMieMtie, 1'b1, "oMieMtie");
    CheckEq1(oMieMeie, 1'b1, "oMieMeie");

    iTimerIrqPending = 1'b1;
    CsrRead(LP_CSR_MIP, data);
    CheckEq32(data & 32'h0000_0080, 32'h0000_0080, "hardware MTIP readback");
    CheckEq1(oMipMtip, 1'b1, "hardware oMipMtip");

    iTimerIrqPending = 1'b0;
    CsrWrite(LP_CSR_MIP, 32'h0000_0080);
    CsrRead(LP_CSR_MIP, data);
    CheckEq32(data & 32'h0000_0080, 32'h0000_0080, "software MTIP readback");
    CheckEq1(oMipMtip, 1'b1, "software oMipMtip");

    iTimerIrqPending = 1'b1;
    CsrWrite(LP_CSR_MIP, 32'h0000_0000);
    CsrRead(LP_CSR_MIP, data);
    CheckEq32(data & 32'h0000_0080, 32'h0000_0080, "hardware MTIP survives software clear");

    iTimerIrqPending = 1'b0;
    CsrRead(LP_CSR_MIP, data);
    CheckEq32(data & 32'h0000_0080, 32'h0000_0000, "hardware MTIP clear drops readback");

    $display("[PASS] tb_CsrFile_Timer completed");
    $finish;
  end

  initial begin
    repeat (300) @(posedge iClk);
    $fatal(1, "[FAIL] tb_CsrFile_Timer watchdog expired");
  end

endmodule
