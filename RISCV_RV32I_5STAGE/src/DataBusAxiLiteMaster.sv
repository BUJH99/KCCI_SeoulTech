/*
[MODULE_INFO_START]
Name: DataBusAxiLiteMaster
Role: Native data-bus to AXI4-Lite master bridge for APB-window MMIO requests
Summary:
  - Latches one native memory request and emits one AXI4-Lite read or write transaction
  - Allows write-address and write-data handshakes to complete independently
  - Maps AXI4-Lite response errors back into the native data-bus response
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module DataBusAxiLiteMaster (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iReqValid,
  input  logic        iReqWr,
  input  logic [31:0] iReqAddr,
  input  logic [3:0]  iReqByteEn,
  input  logic [31:0] iReqWdata,
  input  logic        iAxiAwready,
  input  logic        iAxiWready,
  input  logic        iAxiBvalid,
  input  logic [1:0]  iAxiBresp,
  input  logic        iAxiArready,
  input  logic        iAxiRvalid,
  input  logic [31:0] iAxiRdata,
  input  logic [1:0]  iAxiRresp,

  output logic        oRspReady,
  output logic [31:0] oRspRdata,
  output logic        oRspErr,
  output logic [31:0] oAxiAwaddr,
  output logic [2:0]  oAxiAwprot,
  output logic        oAxiAwvalid,
  output logic [31:0] oAxiWdata,
  output logic [3:0]  oAxiWstrb,
  output logic        oAxiWvalid,
  output logic        oAxiBready,
  output logic [31:0] oAxiAraddr,
  output logic [2:0]  oAxiArprot,
  output logic        oAxiArvalid,
  output logic        oAxiRready
);

  localparam logic [1:0] LP_AXI_RESP_OKAY = 2'b00;

  typedef enum logic [2:0] {
    IDLE,
    WRITE_ADDR_DATA,
    WRITE_RESP,
    READ_ADDR,
    READ_DATA
  } state_e;

  state_e state;
  state_e state_d;

  logic [31:0] ReqAddr;
  logic [3:0]  ReqByteEn;
  logic [31:0] ReqWdata;
  logic        AwDone;
  logic        AwDone_d;
  logic        WDone;
  logic        WDone_d;
  logic        AwHandshake;
  logic        WHandshake;
  logic        ArHandshake;

  assign AwHandshake = oAxiAwvalid && iAxiAwready;
  assign WHandshake  = oAxiWvalid && iAxiWready;
  assign ArHandshake = oAxiArvalid && iAxiArready;

  // Native response outputs intentionally remain Mealy to preserve load/store response latency.
  always_comb begin
    oRspReady   = 1'b0;
    oRspRdata   = '0;
    oRspErr     = 1'b0;
    oAxiAwaddr  = ReqAddr;
    oAxiAwprot  = 3'b000;
    oAxiAwvalid = 1'b0;
    oAxiWdata   = ReqWdata;
    oAxiWstrb   = ReqByteEn;
    oAxiWvalid  = 1'b0;
    oAxiBready  = 1'b0;
    oAxiAraddr  = ReqAddr;
    oAxiArprot  = 3'b000;
    oAxiArvalid = 1'b0;
    oAxiRready  = 1'b0;

    unique case (state)
      WRITE_ADDR_DATA: begin
        oAxiAwvalid = !AwDone;
        oAxiWvalid  = !WDone;
      end

      WRITE_RESP: begin
        oAxiBready = 1'b1;
        oRspReady  = iAxiBvalid;
        oRspErr    = iAxiBvalid && (iAxiBresp != LP_AXI_RESP_OKAY);
      end

      READ_ADDR: begin
        oAxiArvalid = 1'b1;
      end

      READ_DATA: begin
        oAxiRready = 1'b1;
        oRspReady  = iAxiRvalid;
        oRspRdata  = iAxiRvalid ? iAxiRdata : '0;
        oRspErr    = iAxiRvalid && (iAxiRresp != LP_AXI_RESP_OKAY);
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

        if (iReqValid) begin
          state_d = iReqWr ? WRITE_ADDR_DATA : READ_ADDR;
        end
      end

      WRITE_ADDR_DATA: begin
        AwDone_d = AwDone || AwHandshake;
        WDone_d  = WDone || WHandshake;

        if ((AwDone || AwHandshake) && (WDone || WHandshake)) begin
          state_d = WRITE_RESP;
        end
      end

      WRITE_RESP: begin
        if (iAxiBvalid) begin
          state_d = IDLE;
        end
      end

      READ_ADDR: begin
        if (ArHandshake) begin
          state_d = READ_DATA;
        end
      end

      READ_DATA: begin
        if (iAxiRvalid) begin
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
      state     <= IDLE;
      ReqAddr   <= '0;
      ReqByteEn <= '0;
      ReqWdata  <= '0;
      AwDone    <= 1'b0;
      WDone     <= 1'b0;
    end else begin
      state  <= state_d;
      AwDone <= AwDone_d;
      WDone  <= WDone_d;

      if ((state == IDLE) && iReqValid) begin
        ReqAddr   <= iReqAddr;
        ReqByteEn <= iReqByteEn;
        ReqWdata  <= iReqWdata;
      end
    end
  end

endmodule
