/*
[MODULE_INFO_START]
Name: Datapath
Role: Register read, execute, bus-facing load/store formatting, CSR execution, and write-back path
Summary:
  - Reuses instruction field extraction for register addressing and CSR addressing
  - Emits a generic data-bus request shape instead of directly instantiating data memory
  - Computes CSR write semantics and MRET intent locally for the single-cycle core
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module Datapath (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic [31:0]             iPc,
  input  logic [31:0]             iInstr,
  input  logic                    iRegWrite,
  input  logic                    iLoadUnsigned,
  input  rv32i_pkg::bus_cmd_e     iBusCmd,
  input  rv32i_pkg::mem_size_e    iMemSize,
  input  rv32i_pkg::alu_a_sel_e   iAluASel,
  input  rv32i_pkg::alu_b_sel_e   iAluBSel,
  input  rv32i_pkg::imm_sel_e     iImmSel,
  input  rv32i_pkg::branch_e      iBranchOp,
  input  rv32i_pkg::wb_sel_e      iWbSel,
  input  rv32i_pkg::alu_op_e      iAluOp,
  input  logic                    iCsrUseImm,
  input  rv32i_pkg::csr_cmd_e     iCsrCmd,
  input  rv32i_pkg::sys_op_e      iSysOp,
  input  logic [31:0]             iCsrRdata,
  input  logic [31:0]             iMemRdDataRaw,
  output logic [31:0]             oAluResult,
  output logic [31:0]             oPcTarget,
  output logic [31:0]             oJalrTarget,
  output logic                    oBranchTaken,
  output logic                    oDataMisaligned,
  output logic [31:0]             oMemAddr,
  output logic [31:0]             oMemWrData,
  output logic [3:0]              oMemByteEn,
  output logic [31:0]             oMemRdData,
  output logic [31:0]             oMemRdDataQualified,
  output logic [31:0]             oRs2Data,
  output logic [11:0]             oCsrAddr,
  output logic                    oCsrWriteEn,
  output logic [31:0]             oCsrWdata,
  output logic                    oMretValid,
  output logic [31:0]             oRdWrData,
  output logic                    oTimingProbe
);

  logic [4:0]  rs1Addr;
  logic [4:0]  rs2Addr;
  logic [4:0]  rdAddr;
  logic [11:0] csrAddr;
  logic [31:0] rs1RdData;
  logic [31:0] rs2RdData;
  logic [31:0] imm;
  logic [31:0] aluA;
  logic [31:0] aluB;
  logic [31:0] aluResult;
  logic [31:0] memAddr;
  logic [31:0] memRdData;
  logic [31:0] memWrDataAligned;
  logic [31:0] rdWrData;
  logic [31:0] memRdDataQualified;
  logic        dataMisaligned;
  logic        branchTaken;
  logic [31:0] pcPlus4;
  logic [3:0]  memByteEn;

  InstrFields uInstrFields (
    .iInstr(iInstr),
    .oOpcode(),
    .oFunct3(),
    .oInstr31To25(),
    .oInstr31To20(csrAddr),
    .oRs1(rs1Addr),
    .oRs2(rs2Addr),
    .oRd(rdAddr)
  );

  Regfile uRegfile (
    .iClk(iClk),
    .iRstn(iRstn),
    .iRs1Addr(rs1Addr),
    .iRs2Addr(rs2Addr),
    .iRdAddr(rdAddr),
    .iRdWrData(rdWrData),
    .iRdWrEn(iRegWrite),
    .oRs1RdData(rs1RdData),
    .oRs2RdData(rs2RdData),
    .oTimingProbe(oTimingProbe)
  );

  ImmGen uImmGen (
    .iInstr(iInstr),
    .iImmSel(iImmSel),
    .oImm(imm)
  );

  AluOperandSel uAluOperandSel (
    .iRs1Data(rs1RdData),
    .iRs2Data(rs2RdData),
    .iPc(iPc),
    .iImm(imm),
    .iAluASel(iAluASel),
    .iAluBSel(iAluBSel),
    .oAluA(aluA),
    .oAluB(aluB)
  );

  Alu uAlu (
    .iA(aluA),
    .iB(aluB),
    .iAluOp(iAluOp),
    .oResult(aluResult)
  );

  PcTargetGen uPcTargetGen (
    .iPc(iPc),
    .iRs1Data(rs1RdData),
    .iImm(imm),
    .oPcTarget(oPcTarget),
    .oJalrTarget(oJalrTarget),
    .oPcPlus4(pcPlus4)
  );

  LoadStoreFormatter uLoadStoreFormatter (
    .iBusCmd(iBusCmd),
    .iMemSize(iMemSize),
    .iLoadUnsigned(iLoadUnsigned),
    .iAddr(aluResult),
    .iStoreData(rs2RdData),
    .iLoadDataRaw(iMemRdDataRaw),
    .oStoreByteEn(memByteEn),
    .oStoreDataAligned(memWrDataAligned),
    .oLoadData(memRdData),
    .oMisaligned(dataMisaligned)
  );

  MemReadQualifier uMemReadQualifier (
    .iMemRdData(memRdData),
    .iMemRead(iBusCmd == rv32i_pkg::BUS_CMD_READ),
    .iDataMisaligned(dataMisaligned),
    .oMemRdDataQualified(memRdDataQualified)
  );

  ExecuteCsrCtrl uExecuteCsrCtrl (
    .iValid(1'b1),
    .iKill(1'b0),
    .iTrapActive(1'b0),
    .iCsrCmd(iCsrCmd),
    .iCsrUseImm(iCsrUseImm),
    .iRs1Addr(rs1Addr),
    .iRs1Data(rs1RdData),
    .iCsrRdata(iCsrRdata),
    .iCsrAddr(csrAddr),
    .iSysOp(iSysOp),
    .oCsrActive(),
    .oCsrWriteEn(oCsrWriteEn),
    .oCsrAddr(oCsrAddr),
    .oCsrWdata(oCsrWdata),
    .oMretValid(oMretValid)
  );

  always_comb begin
    unique case (iWbSel)
      rv32i_pkg::WB_MEM: rdWrData = memRdDataQualified;
      rv32i_pkg::WB_PC4: rdWrData = pcPlus4;
      rv32i_pkg::WB_CSR: rdWrData = iCsrRdata;
      default:           rdWrData = aluResult;
    endcase
  end

  BranchComparator uBranchComparator (
    .iRs1Data(rs1RdData),
    .iRs2Data(rs2RdData),
    .iBranchOp(iBranchOp),
    .oBranchTaken(branchTaken)
  );

  assign memAddr              = aluResult;
  assign oAluResult           = aluResult;
  assign oBranchTaken         = branchTaken;
  assign oDataMisaligned      = dataMisaligned;
  assign oMemAddr             = memAddr;
  assign oMemWrData           = memWrDataAligned;
  assign oMemByteEn           = memByteEn;
  assign oMemRdData           = memRdData;
  assign oMemRdDataQualified  = memRdDataQualified;
  assign oRs2Data             = rs2RdData;
  assign oRdWrData            = rdWrData;

endmodule
