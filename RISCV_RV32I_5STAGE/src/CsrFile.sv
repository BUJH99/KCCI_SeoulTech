/*
[MODULE_INFO_START]
Name: CsrFile
Role: Minimal machine-mode CSR block for the RV32I 5-stage pipeline CPU
Summary:
  - Implements the machine-level CSR subset used for trap entry, interrupt enable, and MRET return
  - Provides combinational CSR reads for EX-stage execution and clocked updates for CSR writes, MRET, and trap entry
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module CsrFile (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic [11:0] iCsrAddr,
  input  logic        iCsrWriteEn,
  input  logic [11:0] iCsrWriteAddr,
  input  logic [31:0] iCsrWriteData,
  input  logic        iMretValid,
  input  logic        iTrapEnterValid,
  input  logic [31:0] iTrapEnterEpc,
  input  logic [31:0] iTrapEnterCause,
  input  logic        iExtIrqPending,

  output logic [31:0] oCsrRdata,
  output logic [31:0] oMtvec,
  output logic [31:0] oMepc,
  output logic        oMstatusMie,
  output logic        oMstatusMpie,
  output logic        oMieMeie,
  output logic        oMipMeip
);

  import rv32i_pkg::*;

  logic        MstatusMie;
  logic        MstatusMpie;
  logic [1:0]  MstatusMpp;
  logic        MieMsie;
  logic        MieMtie;
  logic        MieMeie;
  logic        MipMsipSw;
  logic        MipMtipSw;
  logic        MipMeipSw;
  logic [31:0] Mtvec;
  logic [31:0] Mepc;
  logic [31:0] Mcause;
  logic [31:0] Mscratch;

  logic        MstatusMieNext;
  logic        MstatusMpieNext;
  logic [1:0]  MstatusMppNext;
  logic        MieMsieNext;
  logic        MieMtieNext;
  logic        MieMeieNext;
  logic        MipMsipSwNext;
  logic        MipMtipSwNext;
  logic        MipMeipSwNext;
  logic [31:0] MtvecNext;
  logic [31:0] MepcNext;
  logic [31:0] McauseNext;
  logic [31:0] MscratchNext;

  logic [31:0] MstatusWord;
  logic [31:0] MieWord;
  logic [31:0] MipWord;

  always_comb begin
    MstatusWord = '0;
    MieWord     = '0;
    MipWord     = '0;

    MstatusWord[LP_MSTATUS_MIE_BIT]  = MstatusMie;
    MstatusWord[LP_MSTATUS_MPIE_BIT] = MstatusMpie;
    MstatusWord[LP_MSTATUS_MPP_MSB:LP_MSTATUS_MPP_LSB] = MstatusMpp;
    MieWord[LP_MIE_MSIE_BIT]         = MieMsie;
    MieWord[LP_MIE_MTIE_BIT]         = MieMtie;
    MieWord[LP_MIE_MEIE_BIT]         = MieMeie;
    MipWord[LP_MIP_MSIP_BIT]         = MipMsipSw;
    MipWord[LP_MIP_MTIP_BIT]         = MipMtipSw;
    MipWord[LP_MIP_MEIP_BIT]         = MipMeipSw || iExtIrqPending;
  end

  always_comb begin
    oCsrRdata = '0;

    unique case (iCsrAddr)
      LP_CSR_MSTATUS:  oCsrRdata = MstatusWord;
      LP_CSR_MIE:      oCsrRdata = MieWord;
      LP_CSR_MTVEC:    oCsrRdata = Mtvec;
      LP_CSR_MSCRATCH: oCsrRdata = Mscratch;
      LP_CSR_MEPC:     oCsrRdata = Mepc;
      LP_CSR_MCAUSE:   oCsrRdata = Mcause;
      LP_CSR_MTVAL:    oCsrRdata = '0;
      LP_CSR_MIP:      oCsrRdata = MipWord;
      default: begin
      end
    endcase
  end

  always_comb begin
    MstatusMieNext  = MstatusMie;
    MstatusMpieNext = MstatusMpie;
    MstatusMppNext  = MstatusMpp;
    MieMsieNext     = MieMsie;
    MieMtieNext     = MieMtie;
    MieMeieNext     = MieMeie;
    MipMsipSwNext   = MipMsipSw;
    MipMtipSwNext   = MipMtipSw;
    MipMeipSwNext   = MipMeipSw;
    MtvecNext       = Mtvec;
    MepcNext        = Mepc;
    McauseNext      = Mcause;
    MscratchNext    = Mscratch;

    if (iCsrWriteEn) begin
      unique case (iCsrWriteAddr)
        LP_CSR_MSTATUS: begin
          MstatusMieNext  = iCsrWriteData[LP_MSTATUS_MIE_BIT];
          MstatusMpieNext = iCsrWriteData[LP_MSTATUS_MPIE_BIT];
          MstatusMppNext  = iCsrWriteData[LP_MSTATUS_MPP_MSB:LP_MSTATUS_MPP_LSB];
        end

        LP_CSR_MIE: begin
          MieMsieNext = iCsrWriteData[LP_MIE_MSIE_BIT];
          MieMtieNext = iCsrWriteData[LP_MIE_MTIE_BIT];
          MieMeieNext = iCsrWriteData[LP_MIE_MEIE_BIT];
        end

        LP_CSR_MTVEC: begin
          unique case (iCsrWriteData[LP_MTVEC_MODE_MSB:LP_MTVEC_MODE_LSB])
            LP_MTVEC_MODE_DIRECT,
            LP_MTVEC_MODE_VECTORED: begin
              MtvecNext = iCsrWriteData;
            end

            default: begin
              MtvecNext = {iCsrWriteData[31:2], LP_MTVEC_MODE_DIRECT};
            end
          endcase
        end

        LP_CSR_MSCRATCH: begin
          MscratchNext = iCsrWriteData;
        end

        LP_CSR_MEPC: begin
          MepcNext = {iCsrWriteData[31:2], 2'b00};
        end

        LP_CSR_MCAUSE: begin
          McauseNext = iCsrWriteData;
        end

        LP_CSR_MTVAL: begin
        end

        LP_CSR_MIP: begin
          MipMsipSwNext = iCsrWriteData[LP_MIP_MSIP_BIT];
          MipMtipSwNext = iCsrWriteData[LP_MIP_MTIP_BIT];
          MipMeipSwNext = iCsrWriteData[LP_MIP_MEIP_BIT];
        end

        default: begin
        end
      endcase
    end

    if (iMretValid) begin
      MstatusMieNext  = MstatusMpieNext;
      MstatusMpieNext = 1'b1;
      MstatusMppNext  = LP_MSTATUS_MPP_USER;
    end

    if (iTrapEnterValid) begin
      MepcNext        = {iTrapEnterEpc[31:2], 2'b00};
      McauseNext      = iTrapEnterCause;
      MstatusMpieNext = MstatusMieNext;
      MstatusMieNext  = 1'b0;
      MstatusMppNext  = LP_MSTATUS_MPP_MACHINE;
    end
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      MstatusMie  <= 1'b0;
      MstatusMpie <= 1'b0;
      MstatusMpp  <= LP_MSTATUS_MPP_USER;
      MieMsie     <= 1'b0;
      MieMtie     <= 1'b0;
      MieMeie     <= 1'b0;
      MipMsipSw   <= 1'b0;
      MipMtipSw   <= 1'b0;
      MipMeipSw   <= 1'b0;
      Mtvec       <= '0;
      Mepc        <= '0;
      Mcause      <= '0;
      Mscratch    <= '0;
    end else begin
      MstatusMie  <= MstatusMieNext;
      MstatusMpie <= MstatusMpieNext;
      MstatusMpp  <= MstatusMppNext;
      MieMsie     <= MieMsieNext;
      MieMtie     <= MieMtieNext;
      MieMeie     <= MieMeieNext;
      MipMsipSw   <= MipMsipSwNext;
      MipMtipSw   <= MipMtipSwNext;
      MipMeipSw   <= MipMeipSwNext;
      Mtvec       <= MtvecNext;
      Mepc        <= MepcNext;
      Mcause      <= McauseNext;
      Mscratch    <= MscratchNext;
    end
  end

  assign oMtvec       = Mtvec;
  assign oMepc        = Mepc;
  assign oMstatusMie  = MstatusMie;
  assign oMstatusMpie = MstatusMpie;
  assign oMieMeie     = MieMeie;
  assign oMipMeip     = MipMeipSw || iExtIrqPending;

endmodule
