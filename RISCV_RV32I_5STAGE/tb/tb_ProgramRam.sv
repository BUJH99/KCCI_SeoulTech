`timescale 1ns / 1ps

module tb_ProgramRam;
  logic        iClk;
  logic [31:0] iInstrAddr;
  logic        iInstDmaWrEn;
  logic [31:0] iInstDmaAddr;
  logic [31:0] iInstDmaWdata;
  logic [3:0]  iInstDmaWstrb;
  logic [31:0] oInstr;
  logic [31:0] oInstDmaRdData;

  ProgramRam #(
    .P_ADDR_WIDTH(4),
    .P_BASE_ADDR(32'h0000_1000)
  ) dut (
    .iClk(iClk),
    .iInstrAddr(iInstrAddr),
    .iInstDmaWrEn(iInstDmaWrEn),
    .iInstDmaAddr(iInstDmaAddr),
    .iInstDmaWdata(iInstDmaWdata),
    .iInstDmaWstrb(iInstDmaWstrb),
    .iInstDmaRdEn(1'b0),
    .iInstDmaRdAddr(32'd0),
    .oInstr(oInstr),
    .oInstDmaRdData(oInstDmaRdData)
  );

  always #5 iClk = ~iClk;

  initial begin
    iClk          = 1'b0;
    iInstrAddr    = 32'h0000_1000;
    iInstDmaWrEn  = 1'b0;
    iInstDmaAddr  = 32'h0000_1000;
    iInstDmaWdata = '0;
    iInstDmaWstrb = '0;

    #1;
    if (oInstr !== 32'h0000_0013) begin
      $fatal(1, "[FAIL] ProgramRam default fetch is not NOP");
    end

    @(posedge iClk);
    iInstDmaWrEn  <= 1'b1;
    iInstDmaWdata <= 32'hAABB_CCDD;
    iInstDmaWstrb <= 4'b0101;
    @(posedge iClk);
    iInstDmaWrEn  <= 1'b0;
    iInstDmaWstrb <= '0;
    #1;

    if (oInstr !== 32'h00BB_00DD) begin
      $fatal(1, "[FAIL] ProgramRam byte strobe write mismatch: 0x%08x", oInstr);
    end

    $display("[PASS] tb_ProgramRam");
    $finish;
  end
endmodule
