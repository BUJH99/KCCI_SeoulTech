/*
[TB_INFO_START]
Name: tb_TrapController_Timer
Target: TrapController
Role: Focused machine timer versus external interrupt selection testbench
Scenario:
  - Checks interrupt gating, timer mcause, vectored mtvec target, external priority, and INTC vector use only for external interrupts
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_TrapController_Timer;

  import rv32i_pkg::*;

  IFID_t     iIFID;
  IDEX_t     iIDEX;
  EXMEM_t    iEXMEM;
  logic      iExRedirectValid;
  logic      iIdTrapValid;
  TrapCauseE iIdTrapCause;
  logic      iExTrapValid;
  TrapCauseE iExTrapCause;
  logic      iMemTrapValid;
  TrapCauseE iMemTrapCause;
  logic      iMstatusMie;
  logic      iMieMeie;
  logic      iMipMeip;
  logic      iMieMtie;
  logic      iMipMtip;
  logic [31:0] iMtvec;
  logic      iIntcVectorValid;
  logic [31:0] iIntcVectorPc;
  logic      oTrapCaptureValid;
  logic [31:0] oTrapEnterEpc;
  logic [31:0] oTrapEnterCause;
  logic      oTrapFromEx;
  logic      oTrapFromMem;
  logic      oTrapFromIrq;
  logic      oTrapRedirectValid;
  logic [31:0] oTrapRedirectPc;
  logic      oIrqAccepted;

  TrapController dut (
    .iIFID(iIFID),
    .iIDEX(iIDEX),
    .iEXMEM(iEXMEM),
    .iExRedirectValid(iExRedirectValid),
    .iIdTrapValid(iIdTrapValid),
    .iIdTrapCause(iIdTrapCause),
    .iExTrapValid(iExTrapValid),
    .iExTrapCause(iExTrapCause),
    .iMemTrapValid(iMemTrapValid),
    .iMemTrapCause(iMemTrapCause),
    .iMstatusMie(iMstatusMie),
    .iMieMeie(iMieMeie),
    .iMipMeip(iMipMeip),
    .iMieMtie(iMieMtie),
    .iMipMtip(iMipMtip),
    .iMtvec(iMtvec),
    .iIntcVectorValid(iIntcVectorValid),
    .iIntcVectorPc(iIntcVectorPc),
    .oTrapCaptureValid(oTrapCaptureValid),
    .oTrapEnterEpc(oTrapEnterEpc),
    .oTrapEnterCause(oTrapEnterCause),
    .oTrapFromEx(oTrapFromEx),
    .oTrapFromMem(oTrapFromMem),
    .oTrapFromIrq(oTrapFromIrq),
    .oTrapRedirectValid(oTrapRedirectValid),
    .oTrapRedirectPc(oTrapRedirectPc),
    .oIrqAccepted(oIrqAccepted)
  );

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

  task automatic ClearInputs;
    begin
      iIFID            = '0;
      iIDEX            = '0;
      iEXMEM           = '0;
      iIFID.Valid      = 1'b1;
      iIFID.Pc         = 32'h0000_0040;
      iExRedirectValid = 1'b0;
      iIdTrapValid     = 1'b0;
      iIdTrapCause     = TRAP_NONE;
      iExTrapValid     = 1'b0;
      iExTrapCause     = TRAP_NONE;
      iMemTrapValid    = 1'b0;
      iMemTrapCause    = TRAP_NONE;
      iMstatusMie      = 1'b0;
      iMieMeie         = 1'b0;
      iMipMeip         = 1'b0;
      iMieMtie         = 1'b0;
      iMipMtip         = 1'b0;
      iMtvec           = 32'h0000_0100;
      iIntcVectorValid = 1'b0;
      iIntcVectorPc    = 32'h0000_0200;
      #1;
    end
  endtask

  initial begin
    ClearInputs();
    iMieMtie  = 1'b1;
    iMipMtip  = 1'b1;
    #1;
    CheckEq1(oIrqAccepted, 1'b0, "mstatus.MIE blocks timer");

    ClearInputs();
    iMstatusMie = 1'b1;
    iMipMtip    = 1'b1;
    #1;
    CheckEq1(oIrqAccepted, 1'b0, "mie.MTIE blocks timer");

    ClearInputs();
    iMstatusMie = 1'b1;
    iMieMtie    = 1'b1;
    iMipMtip    = 1'b1;
    #1;
    CheckEq1(oIrqAccepted, 1'b1, "timer accepted");
    CheckEq32(oTrapEnterCause, LP_MCAUSE_MACHINE_TIMER_INT, "timer mcause");
    CheckEq32(oTrapRedirectPc, 32'h0000_0100, "timer direct mtvec");

    iMtvec = 32'h0000_0101;
    #1;
    CheckEq32(oTrapRedirectPc, 32'h0000_011C, "timer vectored mtvec cause 7");

    iIntcVectorValid = 1'b1;
    iIntcVectorPc    = 32'h0000_0300;
    #1;
    CheckEq32(oTrapRedirectPc, 32'h0000_011C, "timer ignores INTC vector");

    ClearInputs();
    iMstatusMie      = 1'b1;
    iMieMeie         = 1'b1;
    iMipMeip         = 1'b1;
    iMieMtie         = 1'b1;
    iMipMtip         = 1'b1;
    iMtvec           = 32'h0000_0101;
    iIntcVectorValid = 1'b1;
    iIntcVectorPc    = 32'h0000_0300;
    #1;
    CheckEq32(oTrapEnterCause, LP_MCAUSE_MACHINE_EXT_INT, "external priority over timer");
    CheckEq32(oTrapRedirectPc, 32'h0000_0300, "external uses INTC vector");

    ClearInputs();
    iMstatusMie   = 1'b1;
    iMieMtie      = 1'b1;
    iMipMtip      = 1'b1;
    iMemTrapValid = 1'b1;
    iEXMEM.Valid  = 1'b1;
    iEXMEM.Pc     = 32'h0000_0080;
    iMemTrapCause = TRAP_LOAD_ACCESS;
    #1;
    CheckEq32(oTrapEnterCause, LP_MCAUSE_LOAD_ACCESS, "synchronous trap priority over timer");

    $display("[PASS] tb_TrapController_Timer completed");
    $finish;
  end

endmodule
