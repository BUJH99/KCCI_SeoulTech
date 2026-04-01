/*
[MODULE_INFO_START]
Name: ApbSlave
Role: Small APB peripheral block for integration and smoke tests
Summary:
  - Exposes a simple ID/control/scratch register map in the APB window
  - Supports byte-strobe writes so the same load/store formatter can drive APB
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module ApbSlave (
  input  logic        iClk,
  input  logic        iRstn,
  input  logic        iPsel,
  input  logic        iPenable,
  input  logic        iPwrite,
  input  logic [31:0] iPaddr,
  input  logic [31:0] iPwdata,
  input  logic [3:0]  iPstrb,
  output logic [31:0] oPrdata,
  output logic        oPready,
  output logic        oPslverr
);

  localparam logic [31:0] LP_ID_VALUE = 32'h4150_4230;

  logic [31:0] regCtrl;
  logic [31:0] regScratch0;
  logic [31:0] regScratch1;
  logic [31:0] regStatus;
  logic [3:0]  wordOffset;
  logic        accessWrite;
  logic        addrValid;

  function automatic logic [31:0] fApplyByteStrobe(
    input logic [31:0] iPrevData,
    input logic [31:0] iNextData,
    input logic [3:0]  iStrbMask
  );
    logic [31:0] dataMasked;
    int unsigned byteLane;
    begin
      dataMasked = iPrevData;

      for (byteLane = 0; byteLane < 4; byteLane = byteLane + 1) begin
        if (iStrbMask[byteLane]) begin
          dataMasked[(byteLane * 8) +: 8] = iNextData[(byteLane * 8) +: 8];
        end
      end

      fApplyByteStrobe = dataMasked;
    end
  endfunction

  assign wordOffset  = iPaddr[5:2];
  assign accessWrite = iPsel && iPenable && iPwrite;
  assign oPready     = 1'b1;
  assign regStatus   = {31'd0, regCtrl[0]};

  always_comb begin
    addrValid = 1'b1;
    oPrdata   = '0;

    unique case (wordOffset)
      4'h0:    oPrdata = LP_ID_VALUE;
      4'h1:    oPrdata = regCtrl;
      4'h2:    oPrdata = regScratch0;
      4'h3:    oPrdata = regScratch1;
      4'h4:    oPrdata = regStatus;
      default: addrValid = 1'b0;
    endcase
  end

  assign oPslverr = iPsel && iPenable && !addrValid;

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      regCtrl     <= '0;
      regScratch0 <= '0;
      regScratch1 <= 32'hCAFE_1234;
    end else if (accessWrite && addrValid) begin
      unique case (wordOffset)
        4'h1: regCtrl     <= fApplyByteStrobe(regCtrl, iPwdata, iPstrb);
        4'h2: regScratch0 <= fApplyByteStrobe(regScratch0, iPwdata, iPstrb);
        4'h3: regScratch1 <= fApplyByteStrobe(regScratch1, iPwdata, iPstrb);
        default: begin
          // Read-only locations ignore writes.
        end
      endcase
    end
  end

endmodule
