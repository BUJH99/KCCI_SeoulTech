/*
[MODULE_INFO_START]
Name: TrapController
Role: Trap-capture and halt-next-state controller for the RV32I 5-stage pipeline CPU
Summary:
  - Preserves the existing MEM > EX > ID trap capture priority used by PipelineControl
  - Produces the trap redirect event and retained halt-state next values without changing the wrapper interface
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TrapController (
  input  rv32i_pkg::IFID_t         iIFID,
  input  rv32i_pkg::IDEX_t         iIDEX,
  input  rv32i_pkg::EXMEM_t        iEXMEM,
  input  logic                     iExRedirectValid,
  input  logic                     iIdTrapValid,
  input  rv32i_pkg::TrapCauseE     iIdTrapCause,
  input  logic                     iExTrapValid,
  input  rv32i_pkg::TrapCauseE     iExTrapCause,
  input  logic                     iMemTrapValid,
  input  rv32i_pkg::TrapCauseE     iMemTrapCause,
  input  logic                     iMstatusMie,
  input  logic                     iMieMeie,
  input  logic                     iMipMeip,
  input  logic [31:0]              iMtvec,
  input  logic                     iIntcVectorValid,
  input  logic [31:0]              iIntcVectorPc,

  output logic                     oTrapCaptureValid,
  output logic [31:0]              oTrapEnterEpc,
  output logic [31:0]              oTrapEnterCause,
  output logic                     oTrapFromEx,
  output logic                     oTrapFromMem,
  output logic                     oTrapFromInterrupt,
  output logic                     oTrapRedirectValid,
  output logic [31:0]              oTrapRedirectPc,
  output logic                     oInterruptAccepted
);

  import rv32i_pkg::*;

  logic InterruptAccept;
  logic TrapIsInterrupt;
  logic TrapIsMachineExtInterrupt;
  logic [30:0] TrapMcauseCode;
  logic [31:0] MtvecBase;
  logic [1:0]  MtvecMode;
  logic [31:0] StandardTrapPc;

  assign InterruptAccept = iIFID.Valid
                        && !iMemTrapValid
                        && !iExTrapValid
                        && !iExRedirectValid
                        && !iIdTrapValid
                        && iMstatusMie
                        && iMieMeie
                        && iMipMeip;

  assign MtvecBase                 = {iMtvec[31:2], 2'b00};
  assign MtvecMode                 = iMtvec[LP_MTVEC_MODE_MSB:LP_MTVEC_MODE_LSB];
  assign TrapIsInterrupt           = McauseIsInterrupt(oTrapEnterCause);
  assign TrapMcauseCode            = McauseCode(oTrapEnterCause);
  assign TrapIsMachineExtInterrupt = (oTrapEnterCause == LP_MCAUSE_MACHINE_EXT_INT);
  assign StandardTrapPc            = (TrapIsInterrupt && (MtvecMode == LP_MTVEC_MODE_VECTORED))
                                   ? (MtvecBase + {TrapMcauseCode[29:0], 2'b00})
                                   : MtvecBase;

  always_comb begin
    oTrapCaptureValid = 1'b0;
    oTrapEnterEpc     = '0;
    oTrapEnterCause   = '0;
    oTrapFromEx       = 1'b0;
    oTrapFromMem      = 1'b0;
    oTrapFromInterrupt = 1'b0;

    if (iMemTrapValid) begin
      oTrapCaptureValid = 1'b1;
      oTrapEnterEpc     = iEXMEM.Pc;
      oTrapEnterCause   = TrapCauseToMcause(iMemTrapCause);
      oTrapFromMem      = 1'b1;
    end else if (iExTrapValid) begin
      oTrapCaptureValid = 1'b1;
      oTrapEnterEpc     = iIDEX.Pc;
      oTrapEnterCause   = TrapCauseToMcause(iExTrapCause);
      oTrapFromEx       = 1'b1;
    end else if (!iExRedirectValid && iIdTrapValid) begin
      oTrapCaptureValid = 1'b1;
      oTrapEnterEpc     = iIFID.Pc;
      oTrapEnterCause   = TrapCauseToMcause(iIdTrapCause);
    end else if (InterruptAccept) begin
      oTrapCaptureValid = 1'b1;
      oTrapEnterEpc     = iIFID.Pc;
      oTrapEnterCause   = LP_MCAUSE_MACHINE_EXT_INT;
      oTrapFromInterrupt = 1'b1;
    end
  end

  assign oTrapRedirectValid = oTrapCaptureValid;
  assign oTrapRedirectPc    = (TrapIsMachineExtInterrupt && iIntcVectorValid)
                            ? iIntcVectorPc
                            : StandardTrapPc;
  assign oInterruptAccepted = InterruptAccept;

endmodule
