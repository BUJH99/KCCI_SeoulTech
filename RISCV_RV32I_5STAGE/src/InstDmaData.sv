/*
[MODULE_INFO_START]
Name: InstDmaData
Role: Instruction DMA payload datapath for ProgramRam writes
Summary:
  - Packs incoming payload bytes into word writes with byte strobes
  - Tracks additive Checksum, completed byte count, and words written
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module InstDmaData (
  input  logic        iClk,
  input  logic        iRst,
  input  logic        iStart,
  input  logic [31:0] iLoadAddr,
  input  logic [31:0] iByteCnt,
  input  logic        iPayloadValid,
  input  logic [7:0]  iPayloadByte,
  input  logic        iPayloadLast,

  output logic        oPayloadReady,
  output logic        oWrDone,
  output logic        oBytesDone,
  output logic [31:0] oActualChecksum,
  output logic [31:0] oWordsWritten,
  output logic        oPramWrEn,
  output logic [31:0] oPramAddr,
  output logic [31:0] oPramWdata,
  output logic [3:0]  oPramWstrb
);

  logic [31:0] BaseAddr;
  logic [31:0] ByteCnt;
  logic [31:0] ByteIdx;
  logic [31:0] Checksum;
  logic [31:0] WordBuffer;
  logic [3:0]  WordWstrb;
  logic [31:0] CurrentAddr;
  logic [1:0]  ByteLane;
  logic [31:0] WrWdata;
  logic [3:0]  WrWstrb;
  logic        PayloadAccepted;
  logic        WrPulse;

  assign oPayloadReady  = 1'b1;
  assign PayloadAccepted = iPayloadValid && oPayloadReady;
  assign CurrentAddr    = BaseAddr + ByteIdx;
  assign ByteLane       = CurrentAddr[1:0];
  assign WrPulse     = PayloadAccepted && ((ByteLane == 2'd3) || iPayloadLast);
  assign oWrDone     = WrPulse;
  assign oBytesDone     = PayloadAccepted && ((ByteIdx + 32'd1) >= ByteCnt);
  assign oActualChecksum = Checksum;
  assign WrWstrb     = WordWstrb | (4'b0001 << ByteLane);

  always_comb begin
    WrWdata = WordBuffer;
    WrWdata[(ByteLane * 8) +: 8] = iPayloadByte;
  end

  always_ff @(posedge iClk or posedge iRst) begin
    if (iRst) begin
      BaseAddr      <= '0;
      ByteCnt     <= '0;
      ByteIdx     <= '0;
      Checksum      <= '0;
      WordBuffer    <= '0;
      WordWstrb     <= '0;
      oWordsWritten <= '0;
      oPramWrEn     <= 1'b0;
      oPramAddr     <= '0;
      oPramWdata    <= '0;
      oPramWstrb    <= '0;
    end else begin
      oPramWrEn <= 1'b0;

      if (iStart) begin
        BaseAddr      <= iLoadAddr;
        ByteCnt     <= iByteCnt;
        ByteIdx     <= '0;
        Checksum      <= '0;
        WordBuffer    <= '0;
        WordWstrb     <= '0;
        oWordsWritten <= '0;
        oPramAddr     <= '0;
        oPramWdata    <= '0;
        oPramWstrb    <= '0;
      end else if (PayloadAccepted) begin
        Checksum  <= Checksum + {24'd0, iPayloadByte};
        ByteIdx <= ByteIdx + 32'd1;

        if (WrPulse) begin
          oPramWrEn     <= 1'b1;
          oPramAddr     <= {CurrentAddr[31:2], 2'b00};
          oPramWdata    <= WrWdata;
          oPramWstrb    <= WrWstrb;
          oWordsWritten <= oWordsWritten + 32'd1;
          WordBuffer    <= '0;
          WordWstrb     <= '0;
        end else begin
          WordBuffer <= WrWdata;
          WordWstrb  <= WrWstrb;
        end
      end
    end
  end

endmodule
