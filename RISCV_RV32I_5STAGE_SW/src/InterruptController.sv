/*
[MODULE_INFO_START]
Name: InterruptController
Role: Minimal MMIO interrupt aggregator for the RV32I 5-stage pipeline CPU
Summary:
  - Collects GPIO and UART interrupt sources, applies a controller-side enable mask, and forwards a single machine-external interrupt
  - Latches pending requests, tracks one in-service source, and exposes PENDING, ENABLE, CLAIM, and COMPLETE registers
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InterruptController (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iPsel,
  input  logic        iPenable,
  input  logic        iPwrite,
  input  logic [11:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iUartIrq,
  input  logic        iGpioIrq,

  output logic [31:0] oPrdata,
  output logic        oPready,
  output logic        oPslverr,
  output logic        oMachineExtIrq
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_PENDING = 12'h000;
  localparam logic [11:0] LP_REG_ENABLE  = 12'h004;
  localparam logic [11:0] LP_REG_CLAIM   = 12'h008;
  localparam logic [11:0] LP_REG_COMPLETE = 12'h00C;

  logic [1:0] RawIrqVec;
  logic [1:0] PendingVec;
  logic [1:0] PendingVecNext;
  logic [1:0] EnableVec;
  logic [1:0] EnableVecNext;
  logic [1:0] InServiceVec;
  logic [1:0] InServiceVecNext;
  logic [1:0] ClaimPendingVec;
  logic [1:0] ClaimSelVec;
  logic [1:0] CompleteSelVec;
  logic       ClaimReadEn;
  logic       CompleteWriteEn;

  logic [31:0] PendingWord;
  logic [31:0] EnableWord;
  logic [31:0] EnableWriteWord;
  logic [31:0] ClaimWord;
  logic [31:0] CompleteWriteWord;
  logic        AccessEn;

  assign RawIrqVec         = {iUartIrq, iGpioIrq};
  assign PendingWord       = {30'd0, PendingVec};
  assign EnableWord        = {30'd0, EnableVec};
  assign EnableWriteWord   = ByteWriteMerge(EnableWord, iPwdata, iPstrb);
  assign CompleteWriteWord = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign AccessEn          = iPsel && iPenable && oPready;
  assign ClaimReadEn       = AccessEn && !iPwrite && (iPaddr == LP_REG_CLAIM);
  assign CompleteWriteEn   = AccessEn && iPwrite && (iPaddr == LP_REG_COMPLETE);

  assign ClaimPendingVec = PendingVec & EnableVec;

  always_comb begin
    ClaimWord = 32'd0;
    ClaimSelVec = '0;

    // Fixed priority for v1: GPIO > UART
    if (ClaimPendingVec[0]) begin
      ClaimSelVec = 2'b01;
      ClaimWord = 32'd1;
    end else if (ClaimPendingVec[1]) begin
      ClaimSelVec = 2'b10;
      ClaimWord = 32'd2;
    end
  end

  always_comb begin
    CompleteSelVec = '0;

    unique case (CompleteWriteWord[1:0])
      2'd1: CompleteSelVec = 2'b01;
      2'd2: CompleteSelVec = 2'b10;
      default: begin
      end
    endcase
  end

  always_comb begin
    oPrdata  = '0;
    oPslverr = 1'b0;

    if (AccessEn) begin
      unique case (iPaddr)
        LP_REG_PENDING: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = PendingWord;
          end
        end

        LP_REG_ENABLE: begin
          if (!iPwrite) begin
            oPrdata = EnableWord;
          end
        end

        LP_REG_CLAIM: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = ClaimWord;
          end
        end

        LP_REG_COMPLETE: begin
          if (!iPwrite) begin
            oPslverr = 1'b1;
          end
        end

        default: begin
          oPslverr = 1'b1;
        end
      endcase
    end
  end

  always_comb begin
    EnableVecNext  = EnableVec;
    PendingVecNext = PendingVec;
    InServiceVecNext = InServiceVec;

    if (AccessEn && iPwrite && (iPaddr == LP_REG_ENABLE)) begin
      EnableVecNext = EnableWriteWord[1:0];
    end

    if (ClaimReadEn && (ClaimSelVec != '0)) begin
      PendingVecNext   = PendingVecNext & ~ClaimSelVec;
      InServiceVecNext = ClaimSelVec;
    end

    if (CompleteWriteEn && (CompleteSelVec == InServiceVec)) begin
      InServiceVecNext = '0;
    end

    // Re-latch level-sensitive sources unless they are already pending or
    // currently marked in service by a prior CLAIM that has not been COMPLETED.
    if (RawIrqVec[0] && !PendingVecNext[0] && !InServiceVecNext[0]) begin
      PendingVecNext[0] = 1'b1;
    end

    if (RawIrqVec[1] && !PendingVecNext[1] && !InServiceVecNext[1]) begin
      PendingVecNext[1] = 1'b1;
    end
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      PendingVec   <= '0;
      EnableVec    <= '0;
      InServiceVec <= '0;
    end else begin
      PendingVec   <= PendingVecNext;
      EnableVec    <= EnableVecNext;
      InServiceVec <= InServiceVecNext;
    end
  end

  assign oPready        = 1'b1;
  assign oMachineExtIrq = |ClaimPendingVec;

endmodule
