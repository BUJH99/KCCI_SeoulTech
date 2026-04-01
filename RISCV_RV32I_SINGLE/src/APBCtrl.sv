/*
[MODULE_INFO_START]
Name: APBCtrl
Role: APB master control path for request latching, phase sequencing, and response capture
Summary:
  - Latches a single outstanding native-bus request and holds APB address/control/data stable across SETUP and ACCESS
  - Tracks the IDLE, SETUP, and ACCESS phases and publishes completion to the core-side response path
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module APBCtrl (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iApbSel,
  input  logic        iPwrite,
  input  logic [31:0] iPaddr,
  input  logic [3:0]  iPstrb,
  input  logic [31:0] iPwdata,
  input  logic        iAccessComplete,
  input  logic [31:0] iCompletionPrdata,
  input  logic        iCompletionPslverr,

  output logic [31:0] oReqAddr,
  output logic        oApbPhaseActive,
  output logic        oPwrite,
  output logic [11:0] oPaddr,
  output logic [3:0]  oPstrb,
  output logic [31:0] oPwdata,
  output logic        oPenable,
  output logic        oRspReady,
  output logic [31:0] oPrdata,
  output logic        oPslverr
);

  typedef enum logic [1:0] {
    LP_APB_STATE_IDLE,
    LP_APB_STATE_SETUP,
    LP_APB_STATE_ACCESS
  } apb_state_e;

  apb_state_e ApbState;
  apb_state_e ApbState_d;

  logic        ReqWrite;
  logic [31:0] ReqAddr;
  logic [3:0]  ReqStrb;
  logic [31:0] ReqWdata;
  logic [31:0] RspPrdata;
  logic        RspPslverr;

  assign oReqAddr        = ReqAddr;
  assign oApbPhaseActive = (ApbState != LP_APB_STATE_IDLE);
  assign oPwrite         = ReqWrite;
  assign oPaddr          = ReqAddr[11:0];
  assign oPstrb          = ReqStrb;
  assign oPwdata         = ReqWdata;
  assign oPenable        = (ApbState == LP_APB_STATE_ACCESS);

  always_comb begin
    ApbState_d = ApbState;

    unique case (ApbState)
      LP_APB_STATE_IDLE: begin
        if (iApbSel) begin
          ApbState_d = LP_APB_STATE_SETUP;
        end
      end

      LP_APB_STATE_SETUP: begin
        ApbState_d = LP_APB_STATE_ACCESS;
      end

      LP_APB_STATE_ACCESS: begin
        if (iAccessComplete) begin
          ApbState_d = LP_APB_STATE_IDLE;
        end
      end

      default: begin
        ApbState_d = LP_APB_STATE_IDLE;
      end
    endcase
  end

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      ApbState   <= LP_APB_STATE_IDLE;
      ReqWrite   <= 1'b0;
      ReqAddr    <= '0;
      ReqStrb    <= '0;
      ReqWdata   <= '0;
      RspPrdata  <= '0;
      RspPslverr <= 1'b0;
    end else begin
      ApbState <= ApbState_d;

      if ((ApbState == LP_APB_STATE_IDLE) && iApbSel) begin
        ReqWrite <= iPwrite;
        ReqAddr  <= iPaddr;
        ReqStrb  <= iPstrb;
        ReqWdata <= iPwdata;
      end

      if (iAccessComplete) begin
        RspPrdata  <= iCompletionPrdata;
        RspPslverr <= iCompletionPslverr;
      end
    end
  end

  assign oRspReady = iAccessComplete;
  assign oPrdata   = iAccessComplete ? iCompletionPrdata : RspPrdata;
  assign oPslverr  = iAccessComplete ? iCompletionPslverr : RspPslverr;

endmodule
