/*
[MODULE_INFO_START]
Name: rv32i_pkg
Role: Shared package for RV32I single-cycle CPU types and constants
Summary:
  - Declares ALU and write-back enums
  - Defines opcode constants used by decode logic
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

package rv32i_pkg;
  typedef enum logic [1:0] {
    BUS_CMD_IDLE,
    BUS_CMD_READ,
    BUS_CMD_WRITE
  } bus_cmd_e;

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
  } alu_op_e;

  typedef enum logic [1:0] {
    WB_ALU,
    WB_MEM,
    WB_PC4,
    WB_CSR
  } wb_sel_e;

  typedef enum logic [2:0] {
    IMM_NONE,
    IMM_I,
    IMM_S,
    IMM_B,
    IMM_U,
    IMM_J
  } imm_sel_e;

  typedef enum logic [1:0] {
    ALUA_RS1,
    ALUA_PC,
    ALUA_ZERO
  } alu_a_sel_e;

  typedef enum logic {
    ALUB_RS2,
    ALUB_IMM
  } alu_b_sel_e;

  typedef enum logic [1:0] {
    PC_PLUS4,
    PC_BRANCH,
    PC_JAL,
    PC_JALR
  } pc_sel_e;

  typedef enum logic [2:0] {
    BR_NONE,
    BR_EQ,
    BR_NE,
    BR_LT,
    BR_GE,
    BR_LTU,
    BR_GEU
  } branch_e;

  typedef enum logic [1:0] {
    MEM_BYTE,
    MEM_HALF,
    MEM_WORD
  } mem_size_e;

  typedef enum logic [2:0] {
    SYS_NONE,
    SYS_FENCE,
    SYS_ECALL,
    SYS_EBREAK,
    SYS_MRET
  } sys_op_e;

  typedef enum logic [1:0] {
    CSR_NONE,
    CSR_RW,
    CSR_RS,
    CSR_RC
  } csr_cmd_e;

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
  } trap_cause_e;

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
  } opcode_class_e;

  typedef alu_op_e      AluOpE;
  typedef wb_sel_e      WbSelE;
  typedef imm_sel_e     ImmSelE;
  typedef alu_a_sel_e   AluASelE;
  typedef alu_b_sel_e   AluBSelE;
  typedef pc_sel_e      PcSelE;
  typedef branch_e      BranchE;
  typedef mem_size_e    MemSizeE;
  typedef sys_op_e      SysOpE;
  typedef csr_cmd_e     CsrCmdE;
  typedef trap_cause_e  TrapCauseE;
  typedef opcode_class_e OpcodeClassE;

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

  localparam logic [31:0] LP_APB_BASE_ADDR  = LP_APB_UART_BASE;
  localparam logic [31:0] LP_APB_ADDR_MASK  = 32'hFFFF_F000;

  localparam logic [31:0] LP_MCAUSE_ILLEGAL          = 32'd2;
  localparam logic [31:0] LP_MCAUSE_BREAKPOINT       = 32'd3;
  localparam logic [31:0] LP_MCAUSE_LOAD_MISALIGNED  = 32'd4;
  localparam logic [31:0] LP_MCAUSE_LOAD_ACCESS      = 32'd5;
  localparam logic [31:0] LP_MCAUSE_STORE_MISALIGNED = 32'd6;
  localparam logic [31:0] LP_MCAUSE_STORE_ACCESS     = 32'd7;
  localparam logic [31:0] LP_MCAUSE_ECALL_MMODE      = 32'd11;
  localparam logic [31:0] LP_MCAUSE_MACHINE_EXT_INT  = 32'h8000_000B;

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

  function automatic logic [31:0] TrapCauseToMcause(input trap_cause_e iTrapCause);
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
    logic [31:0] mergedData;
    int unsigned byteIdx;
    begin
      mergedData = iPrevData;

      for (byteIdx = 0; byteIdx < 4; byteIdx = byteIdx + 1) begin
        if (iByteEn[byteIdx]) begin
          mergedData[(byteIdx * 8) +: 8] = iWriteData[(byteIdx * 8) +: 8];
        end
      end

      ByteWriteMerge = mergedData;
    end
  endfunction
endpackage
