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
  input  logic        iRst,
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
    IDLE,
    SETUP,
    ACCESS
  } state_e;

  state_e state;
  state_e state_d;

  logic        ReqWr;
  logic [31:0] ReqAddr;
  logic [3:0]  ReqStrb;
  logic [31:0] ReqWdata;
  logic [31:0] RspPrdata;
  logic        RspPslverr;

  always_comb begin
    state_d = state;

    unique case (state)
      IDLE: begin
        if (iApbSel) begin
          state_d = SETUP;
        end
      end

      SETUP: begin
        state_d = ACCESS;
      end

      ACCESS: begin
        if (iAccessComplete) begin
          state_d = IDLE;
        end
      end

      default: begin
        state_d = IDLE;
      end
    endcase
  end

  always_comb begin
    oReqAddr        = ReqAddr;
    oApbPhaseActive = (state != IDLE);
    oPwrite         = ReqWr;
    oPaddr          = ReqAddr[11:0];
    oPstrb          = ReqStrb;
    oPwdata         = ReqWdata;
    oPenable        = (state == ACCESS);
    oRspReady       = iAccessComplete;
    oPrdata         = RspPrdata;
    oPslverr        = RspPslverr;

    if (iAccessComplete) begin
      oPrdata  = iCompletionPrdata;
      oPslverr = iCompletionPslverr;
    end
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state      <= IDLE;
      ReqWr   <= 1'b0;
      ReqAddr    <= '0;
      ReqStrb    <= '0;
      ReqWdata   <= '0;
      RspPrdata  <= '0;
      RspPslverr <= 1'b0;
    end else begin
      state <= state_d;

      if ((state == IDLE) && iApbSel) begin
        ReqWr <= iPwrite;
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

endmodule
