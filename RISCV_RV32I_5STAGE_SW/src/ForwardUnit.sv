/*
[MODULE_INFO_START]
Name: ForwardUnit
Role: Standard EX-stage forwarding selector for the RV32I 5-stage pipeline CPU
Summary:
  - Selects EX operands from the register file, EX/MEM, or MEM/WB sources
  - Prioritizes the newer EX/MEM result over MEM/WB when both target the same source register
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ForwardUnit (
  input  rv32i_pkg::IDEX_t        iIDEX,
  input  rv32i_pkg::EXMEM_t       iEXMEM,
  input  logic                    iWbWriteEn,
  input  logic [4:0]              iWbRdAddr,

  output rv32i_pkg::ForwardSelE oRs1FwdSel,
  output rv32i_pkg::ForwardSelE oRs2FwdSel
);

  import rv32i_pkg::*;

  logic EXMEMFwdCtrl;
  logic EXMEMFwdRs1;
  logic EXMEMFwdRs2;
  logic MEMWBFwdRs1;
  logic MEMWBFwdRs2;

  always_comb begin
    // EX/MEM forwarding control
    EXMEMFwdCtrl = iEXMEM.Valid
                && !iEXMEM.Kill
                && iEXMEM.RegWrite
                && iEXMEM.RdValid
                && (iEXMEM.RdAddr != '0)
                && (iEXMEM.WbSel != WB_MEM);

    // Forwarding-source matches
    EXMEMFwdRs1 = EXMEMFwdCtrl
               && iIDEX.UseRs1
               && (iIDEX.Rs1Addr != '0)
               && (iEXMEM.RdAddr == iIDEX.Rs1Addr);
    EXMEMFwdRs2 = EXMEMFwdCtrl
               && iIDEX.UseRs2
               && (iIDEX.Rs2Addr != '0)
               && (iEXMEM.RdAddr == iIDEX.Rs2Addr);

    MEMWBFwdRs1 = iWbWriteEn
               && iIDEX.UseRs1
               && (iIDEX.Rs1Addr != '0)
               && (iWbRdAddr == iIDEX.Rs1Addr);
    MEMWBFwdRs2 = iWbWriteEn
               && iIDEX.UseRs2
               && (iIDEX.Rs2Addr != '0)
               && (iWbRdAddr == iIDEX.Rs2Addr);

    // Youngest-source priority
    oRs1FwdSel = FWD_NONE;
    if      (EXMEMFwdRs1) oRs1FwdSel = FWD_EX_MEM;
    else if (MEMWBFwdRs1) oRs1FwdSel = FWD_MEM_WB;

    oRs2FwdSel = FWD_NONE;
    if      (EXMEMFwdRs2) oRs2FwdSel = FWD_EX_MEM;
    else if (MEMWBFwdRs2) oRs2FwdSel = FWD_MEM_WB;
  end

endmodule
