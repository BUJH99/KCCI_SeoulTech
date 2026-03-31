/*
[MODULE_INFO_START]
Name: rv32i_pkg
Role: Shared package for RV32I 5-stage pipeline CPU types and constants
Summary:
  - Preserves the ISA-visible enums and opcode constants from the single-cycle core
  - Adds packed control and pipeline-bundle types for the 5-stage implementation
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

package rv32i_pkg;
  typedef enum logic [3:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA,
    ALU_OR,
    ALU_AND
  } AluOpE;

  typedef enum logic [1:0] {
    WB_ALU,
    WB_MEM,
    WB_PC4
  } WbSelE;

  typedef enum logic [2:0] {
    IMM_NONE,
    IMM_I,
    IMM_S,
    IMM_B,
    IMM_U,
    IMM_J
  } ImmSelE;

  typedef enum logic [1:0] {
    ALUA_RS1,
    ALUA_PC,
    ALUA_ZERO
  } AluASelE;

  typedef enum logic {
    ALUB_RS2,
    ALUB_IMM
  } AluBSelE;

  typedef enum logic [1:0] {
    PC_PLUS4,
    PC_BRANCH,
    PC_JAL,
    PC_JALR
  } PcSelE;

  typedef enum logic [2:0] {
    BR_NONE,
    BR_EQ,
    BR_NE,
    BR_LT,
    BR_GE,
    BR_LTU,
    BR_GEU
  } BranchE;

  typedef enum logic [1:0] {
    MEM_BYTE,
    MEM_HALF,
    MEM_WORD
  } MemSizeE;

  typedef enum logic [2:0] {
    SYS_NONE,
    SYS_FENCE,
    SYS_ECALL,
    SYS_EBREAK,
    SYS_MRET
  } SysOpE;

  typedef enum logic [1:0] {
    CSR_NONE,
    CSR_RW,
    CSR_RS,
    CSR_RC
  } CsrCmdE;

  typedef enum logic [3:0] {
    OPCODE_CLASS_RTYPE,
    OPCODE_CLASS_OPIMM,
    OPCODE_CLASS_LOAD,
    OPCODE_CLASS_STORE,
    OPCODE_CLASS_BRANCH,
    OPCODE_CLASS_UPPER_IMM,
    OPCODE_CLASS_JUMP,
    OPCODE_CLASS_SYSTEM,
    OPCODE_CLASS_ILLEGAL
  } OpcodeClassE;

  typedef enum logic [1:0] {
    FWD_NONE,
    FWD_EX_MEM,
    FWD_MEM_WB
  } ForwardSelE;

  typedef enum logic [3:0] {
    TRAP_NONE,
    TRAP_ILLEGAL,
    TRAP_ECALL,
    TRAP_EBREAK,
    TRAP_INSTR_MISALIGNED,
    TRAP_LOAD_MISALIGNED,
    TRAP_STORE_MISALIGNED,
    TRAP_LOAD_ACCESS,
    TRAP_STORE_ACCESS
  } TrapCauseE;

  typedef struct packed {
    logic        ReqValid;
    logic        ReqWrite;
    logic [31:0] ReqAddr;
    logic [3:0]  ReqByteEn;
    logic [31:0] ReqWdata;
  } DataBusReq_t;

  typedef struct packed {
    logic [31:0] RspRdata;
    logic        RspReady;
    logic        RspErr;
  } DataBusRsp_t;

  typedef struct packed {
    logic        RegWrite;
    logic        MemRead;
    logic        MemWrite;
    logic        LoadUnsigned;
    logic        CsrUseImm;
    MemSizeE   MemSize;
    AluASelE  AluASel;
    AluBSelE  AluBSel;
    ImmSelE    ImmSel;
    BranchE     BranchOp;
    PcSelE     PcSel;
    WbSelE     WbSel;
    AluOpE     AluOp;
    SysOpE     SysOp;
    CsrCmdE    CsrCmd;
  } CTRL_t;

  typedef struct packed {
    CTRL_t       Ctrl;
    logic        TrapReq;
    logic        Illegal;
  } CTRL_DEC_t;

  typedef struct packed {
    logic        Valid;
    logic [31:0] Pc;
    logic [31:0] Instr;
  } IFID_t;

  typedef struct packed {
    logic         Valid;
    logic         Kill;
    logic         RdValid;
    logic [31:0]  Pc;
    logic [4:0]   Rs1Addr;
    logic [4:0]   Rs2Addr;
    logic [4:0]   RdAddr;
    logic         UseRs1;
    logic         UseRs2;
    logic [31:0]  Rs1Data;
    logic [31:0]  Rs2Data;
    logic [31:0]  Imm;
    logic [11:0]  CsrAddr;
    CTRL_t        Ctrl;
    TrapCauseE  TrapCause;
  } IDEX_t;

  typedef struct packed {
    logic         Valid;
    logic         Kill;
    logic         RdValid;
    logic [31:0]  Pc;
    logic [4:0]   RdAddr;
    logic [31:0]  AluResult;
    logic [31:0]  ExFwdData;
    logic [31:0]  StoreData;
    logic [31:0]  PcPlus4;
    WbSelE      WbSel;
    logic         RegWrite;
    logic         MemRead;
    logic         MemWrite;
    logic         LoadUnsigned;
    MemSizeE    MemSize;
    TrapCauseE  TrapCause;
  } EXMEM_t;

  typedef struct packed {
    logic         Valid;
    logic         Kill;
    logic         RdValid;
    logic [31:0]  Pc;
    logic [4:0]   RdAddr;
    logic [31:0]  AluResult;
    logic [31:0]  MemRdData;
    logic [31:0]  PcPlus4;
    WbSelE      WbSel;
    logic         RegWrite;
    TrapCauseE  TrapCause;
  } MEMWB_t;

  localparam CTRL_t LP_CTRL_DEFAULT = '{
    RegWrite:     1'b0,
    MemRead:      1'b0,
    MemWrite:     1'b0,
    LoadUnsigned: 1'b0,
    CsrUseImm:    1'b0,
    MemSize:      MEM_WORD,
    AluASel:      ALUA_RS1,
    AluBSel:      ALUB_RS2,
    ImmSel:       IMM_NONE,
    BranchOp:     BR_NONE,
    PcSel:        PC_PLUS4,
    WbSel:        WB_ALU,
    AluOp:        ALU_ADD,
    SysOp:        SYS_NONE,
    CsrCmd:       CSR_NONE
  };

  localparam CTRL_DEC_t LP_CTRL_DEC_DEFAULT = '{
    Ctrl:    LP_CTRL_DEFAULT,
    TrapReq: 1'b0,
    Illegal: 1'b0
  };

  localparam logic [6:0] LP_OPCODE_LOAD     = 7'b0000011;
  localparam logic [6:0] LP_OPCODE_MISCMEM  = 7'b0001111;
  localparam logic [6:0] LP_OPCODE_OPIMM    = 7'b0010011;
  localparam logic [6:0] LP_OPCODE_AUIPC    = 7'b0010111;
  localparam logic [6:0] LP_OPCODE_STORE    = 7'b0100011;
  localparam logic [6:0] LP_OPCODE_RTYPE    = 7'b0110011;
  localparam logic [6:0] LP_OPCODE_LUI      = 7'b0110111;
  localparam logic [6:0] LP_OPCODE_BRANCH   = 7'b1100011;
  localparam logic [6:0] LP_OPCODE_JALR     = 7'b1100111;
  localparam logic [6:0] LP_OPCODE_JAL      = 7'b1101111;
  localparam logic [6:0] LP_OPCODE_SYSTEM   = 7'b1110011;

  localparam logic [11:0] LP_SYSTEM_ECALL   = 12'h000;
  localparam logic [11:0] LP_SYSTEM_EBREAK  = 12'h001;
  localparam logic [11:0] LP_SYSTEM_MRET    = 12'h302;

  localparam logic [11:0] LP_CSR_MSTATUS    = 12'h300;
  localparam logic [11:0] LP_CSR_MIE        = 12'h304;
  localparam logic [11:0] LP_CSR_MTVEC      = 12'h305;
  localparam logic [11:0] LP_CSR_MSCRATCH   = 12'h340;
  localparam logic [11:0] LP_CSR_MEPC       = 12'h341;
  localparam logic [11:0] LP_CSR_MCAUSE     = 12'h342;
  localparam logic [11:0] LP_CSR_MIP        = 12'h344;

  localparam int unsigned LP_MSTATUS_MIE_BIT  = 3;
  localparam int unsigned LP_MSTATUS_MPIE_BIT = 7;
  localparam int unsigned LP_MIE_MEIE_BIT     = 11;
  localparam int unsigned LP_MIP_MEIP_BIT     = 11;

  localparam logic [31:0] LP_DATA_RAM_BASE  = 32'h0000_0000;
  localparam logic [31:0] LP_DATA_RAM_LAST  = 32'h0000_03FF;
  localparam logic [31:0] LP_APB_UART_BASE  = 32'h4000_0000;
  localparam logic [31:0] LP_APB_GPIO_BASE  = 32'h4000_1000;
  localparam logic [31:0] LP_APB_FND_BASE   = 32'h4000_2000;
  localparam logic [31:0] LP_APB_INTC_BASE  = 32'h4000_3000;

  localparam logic [31:0] LP_MCAUSE_ILLEGAL             = 32'd2;
  localparam logic [31:0] LP_MCAUSE_BREAKPOINT          = 32'd3;
  localparam logic [31:0] LP_MCAUSE_LOAD_MISALIGNED     = 32'd4;
  localparam logic [31:0] LP_MCAUSE_LOAD_ACCESS         = 32'd5;
  localparam logic [31:0] LP_MCAUSE_STORE_MISALIGNED    = 32'd6;
  localparam logic [31:0] LP_MCAUSE_STORE_ACCESS        = 32'd7;
  localparam logic [31:0] LP_MCAUSE_ECALL_MMODE         = 32'd11;
  localparam logic [31:0] LP_MCAUSE_MACHINE_EXT_INT     = 32'h8000_000B;

  function automatic logic IsSupportedCsrAddr(input logic [11:0] iCsrAddr);
    begin
      unique case (iCsrAddr)
        LP_CSR_MSTATUS,
        LP_CSR_MIE,
        LP_CSR_MTVEC,
        LP_CSR_MSCRATCH,
        LP_CSR_MEPC,
        LP_CSR_MCAUSE,
        LP_CSR_MIP: IsSupportedCsrAddr = 1'b1;
        default:    IsSupportedCsrAddr = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [31:0] TrapCauseToMcause(input TrapCauseE iTrapCause);
    begin
      unique case (iTrapCause)
        TRAP_ILLEGAL:          TrapCauseToMcause = LP_MCAUSE_ILLEGAL;
        TRAP_ECALL:            TrapCauseToMcause = LP_MCAUSE_ECALL_MMODE;
        TRAP_EBREAK:           TrapCauseToMcause = LP_MCAUSE_BREAKPOINT;
        TRAP_INSTR_MISALIGNED: TrapCauseToMcause = 32'd0;
        TRAP_LOAD_MISALIGNED:  TrapCauseToMcause = LP_MCAUSE_LOAD_MISALIGNED;
        TRAP_STORE_MISALIGNED: TrapCauseToMcause = LP_MCAUSE_STORE_MISALIGNED;
        TRAP_LOAD_ACCESS:      TrapCauseToMcause = LP_MCAUSE_LOAD_ACCESS;
        TRAP_STORE_ACCESS:     TrapCauseToMcause = LP_MCAUSE_STORE_ACCESS;
        default:               TrapCauseToMcause = 32'd0;
      endcase
    end
  endfunction

  function automatic logic [31:0] ByteWriteMerge(
    input logic [31:0] iPrevData,
    input logic [31:0] iWriteData,
    input logic [3:0]  iByteEn
  );
    logic [31:0] MergedData;
    int unsigned ByteIdx;
    begin
      MergedData = iPrevData;
      for (ByteIdx = 0; ByteIdx < 4; ByteIdx = ByteIdx + 1) begin
        if (iByteEn[ByteIdx]) begin
          MergedData[(ByteIdx * 8) +: 8] = iWriteData[(ByteIdx * 8) +: 8];
        end
      end
      ByteWriteMerge = MergedData;
    end
  endfunction
endpackage
