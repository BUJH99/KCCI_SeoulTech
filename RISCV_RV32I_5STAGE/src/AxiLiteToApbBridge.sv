/*
[MODULE_INFO_START]
Name: AxiLiteToApbBridge
Role: AXI4-Lite slave to APB master bridge for the SoC MMIO peripheral window
Summary:
  - Accepts one AXI4-Lite read or write transaction at a time with write priority
  - Converts accepted transactions into APB SETUP and ACCESS phases
  - Reuses APBMux for peripheral select, completion data, wait states, and local decode errors
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module AxiLiteToApbBridge (
  input  logic        iClk,
  input  logic        iRst,
  input  logic [31:0] iAxiAwaddr,
  input  logic [2:0]  iAxiAwprot,
  input  logic        iAxiAwvalid,
  input  logic [31:0] iAxiWdata,
  input  logic [3:0]  iAxiWstrb,
  input  logic        iAxiWvalid,
  input  logic        iAxiBready,
  input  logic [31:0] iAxiAraddr,
  input  logic [2:0]  iAxiArprot,
  input  logic        iAxiArvalid,
  input  logic        iAxiRready,
  input  logic [31:0] iUartPrdata,
  input  logic [31:0] iGpioPrdata,
  input  logic [31:0] iI2cPrdata,
  input  logic [31:0] iIntcPrdata,
  input  logic [31:0] iSpiPrdata,
  input  logic [31:0] iFndPrdata,
  input  logic [31:0] iTimerPrdata,
  input  logic [31:0] iInstDmaPrdata,
  input  logic        iUartPready,
  input  logic        iGpioPready,
  input  logic        iI2cPready,
  input  logic        iIntcPready,
  input  logic        iSpiPready,
  input  logic        iFndPready,
  input  logic        iTimerPready,
  input  logic        iInstDmaPready,
  input  logic        iUartPslverr,
  input  logic        iGpioPslverr,
  input  logic        iI2cPslverr,
  input  logic        iIntcPslverr,
  input  logic        iSpiPslverr,
  input  logic        iFndPslverr,
  input  logic        iTimerPslverr,
  input  logic        iInstDmaPslverr,

  output logic        oAxiAwready,
  output logic        oAxiWready,
  output logic        oAxiBvalid,
  output logic [1:0]  oAxiBresp,
  output logic        oAxiArready,
  output logic        oAxiRvalid,
  output logic [31:0] oAxiRdata,
  output logic [1:0]  oAxiRresp,
  output logic        oPwrite,
  output logic [11:0] oPaddr,
  output logic [3:0]  oPstrb,
  output logic [31:0] oPwdata,
  output logic        oPenable,
  output logic        oUartPsel,
  output logic        oGpioPsel,
  output logic        oI2cPsel,
  output logic        oIntcPsel,
  output logic        oSpiPsel,
  output logic        oFndPsel,
  output logic        oTimerPsel,
  output logic        oInstDmaPsel
);

  localparam logic [1:0] LP_AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] LP_AXI_RESP_SLVERR = 2'b10;

  typedef enum logic [3:0] {
    IDLE,
    AXI_WRITE_ACCEPT,
    APB_WRITE_SETUP,
    APB_WRITE_ACCESS,
    AXI_WRITE_RESP,
    APB_READ_SETUP,
    APB_READ_ACCESS,
    AXI_READ_RESP
  } state_e;

  state_e state;
  state_e state_d;

  logic [31:0] ReqAddr;
  logic [3:0]  ReqStrb;
  logic [31:0] ReqWdata;
  logic        ReqWr;
  logic        AwDone;
  logic        AwDone_d;
  logic        WDone;
  logic        WDone_d;
  logic [31:0] RspRdata;
  logic [1:0]  RspRresp;
  logic [1:0]  RspBresp;
  logic        ApbPhaseActive;
  logic        AccessComplete;
  logic [31:0] CompletionPrdata;
  logic        CompletionPslverr;
  logic        AwHandshake;
  logic        WHandshake;
  logic        ArHandshake;
  logic        WrSel;

  assign WrSel = (state == IDLE) && (iAxiAwvalid || iAxiWvalid);

  assign AwHandshake = oAxiAwready && iAxiAwvalid;
  assign WHandshake  = oAxiWready && iAxiWvalid;
  assign ArHandshake = oAxiArready && iAxiArvalid;

  // AXI ready/valid outputs intentionally remain Mealy to preserve zero-cycle acceptance.
  always_comb begin
    oAxiAwready   = 1'b0;
    oAxiWready    = 1'b0;
    oAxiBvalid    = 1'b0;
    oAxiBresp     = RspBresp;
    oAxiArready   = 1'b0;
    oAxiRvalid    = 1'b0;
    oAxiRdata     = RspRdata;
    oAxiRresp     = RspRresp;
    oPwrite       = ReqWr;
    oPaddr        = ReqAddr[11:0];
    oPstrb        = ReqStrb;
    oPwdata       = ReqWdata;
    oPenable      = 1'b0;
    ApbPhaseActive = 1'b0;

    unique case (state)
      IDLE: begin
        oAxiAwready = 1'b1;
        oAxiWready  = 1'b1;
        oAxiArready = !WrSel;
      end

      AXI_WRITE_ACCEPT: begin
        oAxiAwready = !AwDone;
        oAxiWready  = !WDone;
      end

      APB_WRITE_SETUP,
      APB_READ_SETUP: begin
        ApbPhaseActive = 1'b1;
      end

      APB_WRITE_ACCESS: begin
        oPenable       = 1'b1;
        ApbPhaseActive = 1'b1;
      end

      AXI_WRITE_RESP: begin
        oAxiBvalid = 1'b1;
      end

      APB_READ_ACCESS: begin
        oPenable       = 1'b1;
        ApbPhaseActive = 1'b1;
      end

      AXI_READ_RESP: begin
        oAxiRvalid = 1'b1;
      end

      default: begin
      end
    endcase
  end

  always_comb begin
    state_d  = state;
    AwDone_d = AwDone;
    WDone_d  = WDone;

    unique case (state)
      IDLE: begin
        AwDone_d = 1'b0;
        WDone_d  = 1'b0;

        if (WrSel) begin
          AwDone_d = AwHandshake;
          WDone_d  = WHandshake;

          if (AwHandshake && WHandshake) begin
            state_d = APB_WRITE_SETUP;
          end else begin
            state_d = AXI_WRITE_ACCEPT;
          end
        end else if (ArHandshake) begin
          state_d = APB_READ_SETUP;
        end
      end

      AXI_WRITE_ACCEPT: begin
        AwDone_d = AwDone || AwHandshake;
        WDone_d  = WDone || WHandshake;

        if ((AwDone || AwHandshake) && (WDone || WHandshake)) begin
          state_d = APB_WRITE_SETUP;
        end
      end

      APB_WRITE_SETUP: begin
        state_d = APB_WRITE_ACCESS;
      end

      APB_WRITE_ACCESS: begin
        if (AccessComplete) begin
          state_d = AXI_WRITE_RESP;
        end
      end

      AXI_WRITE_RESP: begin
        if (iAxiBready) begin
          state_d = IDLE;
        end
      end

      APB_READ_SETUP: begin
        state_d = APB_READ_ACCESS;
      end

      APB_READ_ACCESS: begin
        if (AccessComplete) begin
          state_d = AXI_READ_RESP;
        end
      end

      AXI_READ_RESP: begin
        if (iAxiRready) begin
          state_d = IDLE;
        end
      end

      default: begin
        state_d = IDLE;
      end
    endcase
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      state    <= IDLE;
      ReqAddr  <= '0;
      ReqStrb  <= '0;
      ReqWdata <= '0;
      ReqWr <= 1'b0;
      AwDone   <= 1'b0;
      WDone    <= 1'b0;
      RspRdata <= '0;
      RspRresp <= LP_AXI_RESP_OKAY;
      RspBresp <= LP_AXI_RESP_OKAY;
    end else begin
      state  <= state_d;
      AwDone <= AwDone_d;
      WDone  <= WDone_d;

      if ((state == IDLE) && WrSel) begin
        ReqWr <= 1'b1;
      end else if (ArHandshake) begin
        ReqWr <= 1'b0;
      end

      if (AwHandshake) begin
        ReqAddr <= iAxiAwaddr;
      end else if (ArHandshake) begin
        ReqAddr <= iAxiAraddr;
      end

      if (WHandshake) begin
        ReqStrb  <= iAxiWstrb;
        ReqWdata <= iAxiWdata;
      end

      if ((state == APB_WRITE_ACCESS) && AccessComplete) begin
        RspBresp <= CompletionPslverr ? LP_AXI_RESP_SLVERR : LP_AXI_RESP_OKAY;
      end

      if ((state == APB_READ_ACCESS) && AccessComplete) begin
        RspRdata <= CompletionPrdata;
        RspRresp <= CompletionPslverr ? LP_AXI_RESP_SLVERR : LP_AXI_RESP_OKAY;
      end
    end
  end

  APBMux uAPBMux (
    .iReqAddr(ReqAddr),
    .iApbPhaseActive(ApbPhaseActive),
    .iPenable(oPenable),
    .iUartPrdata(iUartPrdata),
    .iGpioPrdata(iGpioPrdata),
    .iI2cPrdata(iI2cPrdata),
    .iIntcPrdata(iIntcPrdata),
    .iSpiPrdata(iSpiPrdata),
    .iFndPrdata(iFndPrdata),
    .iTimerPrdata(iTimerPrdata),
    .iInstDmaPrdata(iInstDmaPrdata),
    .iUartPready(iUartPready),
    .iGpioPready(iGpioPready),
    .iI2cPready(iI2cPready),
    .iIntcPready(iIntcPready),
    .iSpiPready(iSpiPready),
    .iFndPready(iFndPready),
    .iTimerPready(iTimerPready),
    .iInstDmaPready(iInstDmaPready),
    .iUartPslverr(iUartPslverr),
    .iGpioPslverr(iGpioPslverr),
    .iI2cPslverr(iI2cPslverr),
    .iIntcPslverr(iIntcPslverr),
    .iSpiPslverr(iSpiPslverr),
    .iFndPslverr(iFndPslverr),
    .iTimerPslverr(iTimerPslverr),
    .iInstDmaPslverr(iInstDmaPslverr),
    .oUartPsel(oUartPsel),
    .oGpioPsel(oGpioPsel),
    .oI2cPsel(oI2cPsel),
    .oIntcPsel(oIntcPsel),
    .oSpiPsel(oSpiPsel),
    .oFndPsel(oFndPsel),
    .oTimerPsel(oTimerPsel),
    .oInstDmaPsel(oInstDmaPsel),
    .oAccessComplete(AccessComplete),
    .oCompletionPrdata(CompletionPrdata),
    .oCompletionPslverr(CompletionPslverr)
  );

endmodule
