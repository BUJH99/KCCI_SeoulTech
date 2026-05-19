/*
[TB_INFO_START]
Name: tb_AxiLiteToApbBridge
Target: AxiLiteToApbBridge
Role: Focused AXI4-Lite slave to APB master protocol testbench
Scenario:
  - Checks AXI write/read acceptance, APB SETUP/ACCESS sequencing, wait states, held AXI responses, APB errors, local decode errors, and write priority
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module tb_AxiLiteToApbBridge;

  import rv32i_pkg::*;

  localparam logic [1:0] LP_AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] LP_AXI_RESP_SLVERR = 2'b10;

  logic        iClk;
  logic        iRst;
  logic [31:0] iAxiAwaddr;
  logic [2:0]  iAxiAwprot;
  logic        iAxiAwvalid;
  logic [31:0] iAxiWdata;
  logic [3:0]  iAxiWstrb;
  logic        iAxiWvalid;
  logic        iAxiBready;
  logic [31:0] iAxiAraddr;
  logic [2:0]  iAxiArprot;
  logic        iAxiArvalid;
  logic        iAxiRready;
  logic [31:0] iUartPrdata;
  logic [31:0] iGpioPrdata;
  logic [31:0] iI2cPrdata;
  logic [31:0] iIntcPrdata;
  logic [31:0] iSpiPrdata;
  logic [31:0] iFndPrdata;
  logic [31:0] iTimerPrdata;
  logic [31:0] iInstDmaPrdata;
  logic        iUartPready;
  logic        iGpioPready;
  logic        iI2cPready;
  logic        iIntcPready;
  logic        iSpiPready;
  logic        iFndPready;
  logic        iTimerPready;
  logic        iInstDmaPready;
  logic        iUartPslverr;
  logic        iGpioPslverr;
  logic        iI2cPslverr;
  logic        iIntcPslverr;
  logic        iSpiPslverr;
  logic        iFndPslverr;
  logic        iTimerPslverr;
  logic        iInstDmaPslverr;
  logic        oAxiAwready;
  logic        oAxiWready;
  logic        oAxiBvalid;
  logic [1:0]  oAxiBresp;
  logic        oAxiArready;
  logic        oAxiRvalid;
  logic [31:0] oAxiRdata;
  logic [1:0]  oAxiRresp;
  logic        oPwrite;
  logic [11:0] oPaddr;
  logic [3:0]  oPstrb;
  logic [31:0] oPwdata;
  logic        oPenable;
  logic        oUartPsel;
  logic        oGpioPsel;
  logic        oI2cPsel;
  logic        oIntcPsel;
  logic        oSpiPsel;
  logic        oFndPsel;
  logic        oTimerPsel;
  logic        oInstDmaPsel;

  AxiLiteToApbBridge dut (
    .iClk(iClk),
    .iRst(iRst),
    .iAxiAwaddr(iAxiAwaddr),
    .iAxiAwprot(iAxiAwprot),
    .iAxiAwvalid(iAxiAwvalid),
    .iAxiWdata(iAxiWdata),
    .iAxiWstrb(iAxiWstrb),
    .iAxiWvalid(iAxiWvalid),
    .iAxiBready(iAxiBready),
    .iAxiAraddr(iAxiAraddr),
    .iAxiArprot(iAxiArprot),
    .iAxiArvalid(iAxiArvalid),
    .iAxiRready(iAxiRready),
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
    .oAxiAwready(oAxiAwready),
    .oAxiWready(oAxiWready),
    .oAxiBvalid(oAxiBvalid),
    .oAxiBresp(oAxiBresp),
    .oAxiArready(oAxiArready),
    .oAxiRvalid(oAxiRvalid),
    .oAxiRdata(oAxiRdata),
    .oAxiRresp(oAxiRresp),
    .oPwrite(oPwrite),
    .oPaddr(oPaddr),
    .oPstrb(oPstrb),
    .oPwdata(oPwdata),
    .oPenable(oPenable),
    .oUartPsel(oUartPsel),
    .oGpioPsel(oGpioPsel),
    .oI2cPsel(oI2cPsel),
    .oIntcPsel(oIntcPsel),
    .oSpiPsel(oSpiPsel),
    .oFndPsel(oFndPsel),
    .oTimerPsel(oTimerPsel),
    .oInstDmaPsel(oInstDmaPsel)
  );

  always #5 iClk = ~iClk;

  task automatic Tick;
    begin
      @(posedge iClk);
      #1;
    end
  endtask

  task automatic CheckEq1(
    input logic  iActual,
    input logic  iExpected,
    input string iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected %0b, got %0b", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq2(
    input logic [1:0] iActual,
    input logic [1:0] iExpected,
    input string      iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected %0b, got %0b", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq4(
    input logic [3:0] iActual,
    input logic [3:0] iExpected,
    input string      iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected 0x%0h, got 0x%0h", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq12(
    input logic [11:0] iActual,
    input logic [11:0] iExpected,
    input string       iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected 0x%03x, got 0x%03x", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckEq32(
    input logic [31:0] iActual,
    input logic [31:0] iExpected,
    input string       iContext
  );
    begin
      if (iActual !== iExpected) begin
        $fatal(1, "[FAIL] %s: expected 0x%08x, got 0x%08x", iContext, iExpected, iActual);
      end
    end
  endtask

  task automatic CheckNoPsel(input string iContext);
    begin
      CheckEq1(oUartPsel, 1'b0, {iContext, " no UART PSEL"});
      CheckEq1(oGpioPsel, 1'b0, {iContext, " no GPIO PSEL"});
      CheckEq1(oI2cPsel, 1'b0, {iContext, " no I2C PSEL"});
      CheckEq1(oIntcPsel, 1'b0, {iContext, " no INTC PSEL"});
      CheckEq1(oSpiPsel, 1'b0, {iContext, " no SPI PSEL"});
      CheckEq1(oFndPsel, 1'b0, {iContext, " no FND PSEL"});
      CheckEq1(oTimerPsel, 1'b0, {iContext, " no TIMER PSEL"});
      CheckEq1(oInstDmaPsel, 1'b0, {iContext, " no INST_DMA PSEL"});
    end
  endtask

  task automatic ResetDut;
    begin
      iRst        = 1'b1;
      iAxiAwaddr   = '0;
      iAxiAwprot   = 3'b000;
      iAxiAwvalid  = 1'b0;
      iAxiWdata    = '0;
      iAxiWstrb    = '0;
      iAxiWvalid   = 1'b0;
      iAxiBready   = 1'b1;
      iAxiAraddr   = '0;
      iAxiArprot   = 3'b000;
      iAxiArvalid  = 1'b0;
      iAxiRready   = 1'b1;
      iUartPrdata  = 32'h1111_0000;
      iGpioPrdata  = 32'h2222_1000;
      iI2cPrdata   = 32'h3333_2000;
      iIntcPrdata  = 32'h4444_3000;
      iSpiPrdata   = 32'h5555_4000;
      iFndPrdata   = 32'h6666_5000;
      iTimerPrdata = 32'h7777_6000;
      iInstDmaPrdata = 32'h8888_7000;
      iUartPready  = 1'b1;
      iGpioPready  = 1'b1;
      iI2cPready   = 1'b1;
      iIntcPready  = 1'b1;
      iSpiPready   = 1'b1;
      iFndPready   = 1'b1;
      iTimerPready = 1'b1;
      iInstDmaPready = 1'b1;
      iUartPslverr = 1'b0;
      iGpioPslverr = 1'b0;
      iI2cPslverr  = 1'b0;
      iIntcPslverr = 1'b0;
      iSpiPslverr  = 1'b0;
      iFndPslverr  = 1'b0;
      iTimerPslverr = 1'b0;
      iInstDmaPslverr = 1'b0;
      repeat (3) Tick();
      iRst = 1'b0;
      Tick();
    end
  endtask

  task automatic CheckTimerSetup(
    input logic [11:0] iAddr,
    input logic        iWrite,
    input logic [3:0]  iStrb,
    input logic [31:0] iWdata,
    input string       iContext
  );
    begin
      CheckEq1(oTimerPsel, 1'b1, {iContext, " TIMER PSEL setup"});
      CheckEq1(oPenable, 1'b0, {iContext, " PENABLE setup low"});
      CheckEq1(oPwrite, iWrite, {iContext, " PWRITE setup"});
      CheckEq12(oPaddr, iAddr, {iContext, " PADDR setup"});
      CheckEq4(oPstrb, iStrb, {iContext, " PSTRB setup"});
      CheckEq32(oPwdata, iWdata, {iContext, " PWDATA setup"});
    end
  endtask

  task automatic CheckTimerAccess(
    input logic [11:0] iAddr,
    input logic        iWrite,
    input logic [3:0]  iStrb,
    input logic [31:0] iWdata,
    input string       iContext
  );
    begin
      CheckEq1(oTimerPsel, 1'b1, {iContext, " TIMER PSEL access"});
      CheckEq1(oPenable, 1'b1, {iContext, " PENABLE access high"});
      CheckEq1(oPwrite, iWrite, {iContext, " PWRITE access"});
      CheckEq12(oPaddr, iAddr, {iContext, " PADDR access"});
      CheckEq4(oPstrb, iStrb, {iContext, " PSTRB access"});
      CheckEq32(oPwdata, iWdata, {iContext, " PWDATA access"});
    end
  endtask

  task automatic CheckGpioSetup(
    input logic [11:0] iAddr,
    input logic        iWrite,
    input logic [3:0]  iStrb,
    input logic [31:0] iWdata,
    input string       iContext
  );
    begin
      CheckEq1(oGpioPsel, 1'b1, {iContext, " GPIO PSEL setup"});
      CheckEq1(oPenable, 1'b0, {iContext, " PENABLE setup low"});
      CheckEq1(oPwrite, iWrite, {iContext, " PWRITE setup"});
      CheckEq12(oPaddr, iAddr, {iContext, " PADDR setup"});
      CheckEq4(oPstrb, iStrb, {iContext, " PSTRB setup"});
      CheckEq32(oPwdata, iWdata, {iContext, " PWDATA setup"});
    end
  endtask

  task automatic CheckGpioAccess(
    input logic [11:0] iAddr,
    input logic        iWrite,
    input logic [3:0]  iStrb,
    input logic [31:0] iWdata,
    input string       iContext
  );
    begin
      CheckEq1(oGpioPsel, 1'b1, {iContext, " GPIO PSEL access"});
      CheckEq1(oPenable, 1'b1, {iContext, " PENABLE access high"});
      CheckEq1(oPwrite, iWrite, {iContext, " PWRITE access"});
      CheckEq12(oPaddr, iAddr, {iContext, " PADDR access"});
      CheckEq4(oPstrb, iStrb, {iContext, " PSTRB access"});
      CheckEq32(oPwdata, iWdata, {iContext, " PWDATA access"});
    end
  endtask

  task automatic BeginWriteBoth(
    input logic [31:0] iAddr,
    input logic [3:0]  iStrb,
    input logic [31:0] iWdata,
    input string       iContext
  );
    begin
      iAxiAwaddr  = iAddr;
      iAxiAwvalid = 1'b1;
      iAxiWdata   = iWdata;
      iAxiWstrb   = iStrb;
      iAxiWvalid  = 1'b1;
      #1;
      CheckEq1(oAxiAwready, 1'b1, {iContext, " AWREADY"});
      CheckEq1(oAxiWready, 1'b1, {iContext, " WREADY"});
      Tick();
      iAxiAwvalid = 1'b0;
      iAxiWvalid  = 1'b0;
      CheckGpioSetup(iAddr[11:0], 1'b1, iStrb, iWdata, iContext);
    end
  endtask

  task automatic FinishWriteFromSetup(
    input logic [1:0] iExpectedResp,
    input string      iContext
  );
    begin
      Tick();
      CheckGpioAccess(oPaddr, 1'b1, oPstrb, oPwdata, {iContext, " access"});
      CheckEq1(oAxiBvalid, 1'b0, {iContext, " BVALID waits through APB access"});
      Tick();
      CheckEq1(oAxiBvalid, 1'b1, {iContext, " BVALID response"});
      CheckEq2(oAxiBresp, iExpectedResp, {iContext, " BRESP"});
    end
  endtask

  task automatic BeginRead(
    input logic [31:0] iAddr,
    input string       iContext
  );
    begin
      iAxiAraddr  = iAddr;
      iAxiArvalid = 1'b1;
      #1;
      CheckEq1(oAxiArready, 1'b1, {iContext, " ARREADY"});
      Tick();
      iAxiArvalid = 1'b0;
      CheckGpioSetup(iAddr[11:0], 1'b0, 4'h0, 32'd0, iContext);
    end
  endtask

  task automatic FinishReadFromSetup(
    input logic [31:0] iExpectedData,
    input logic [1:0]  iExpectedResp,
    input string       iContext
  );
    begin
      Tick();
      CheckGpioAccess(oPaddr, 1'b0, 4'h0, 32'd0, {iContext, " access"});
      CheckEq1(oAxiRvalid, 1'b0, {iContext, " RVALID waits through APB access"});
      Tick();
      CheckEq1(oAxiRvalid, 1'b1, {iContext, " RVALID response"});
      CheckEq32(oAxiRdata, iExpectedData, {iContext, " RDATA"});
      CheckEq2(oAxiRresp, iExpectedResp, {iContext, " RRESP"});
    end
  endtask

  task automatic RunWriteZeroWait;
    begin
      ResetDut();
      BeginWriteBoth(LP_APB_GPIO_BASE, 4'hF, 32'hA5A5_5A5A, "write zero wait");
      FinishWriteFromSetup(LP_AXI_RESP_OKAY, "write zero wait");
    end
  endtask

  task automatic RunReadZeroWait;
    begin
      ResetDut();
      iGpioPrdata = 32'h1234_ABCD;
      BeginRead(LP_APB_GPIO_BASE + 32'h4, "read zero wait");
      FinishReadFromSetup(32'h1234_ABCD, LP_AXI_RESP_OKAY, "read zero wait");
    end
  endtask

  task automatic RunTimerReadZeroWait;
    begin
      ResetDut();
      iTimerPrdata = 32'hCAFE_6000;
      iAxiAraddr  = LP_APB_TIMER_BASE + 32'h18;
      iAxiArvalid = 1'b1;
      #1;
      CheckEq1(oAxiArready, 1'b1, "timer read ARREADY");
      Tick();
      iAxiArvalid = 1'b0;
      CheckTimerSetup(12'h018, 1'b0, 4'h0, 32'd0, "timer read zero wait");
      Tick();
      CheckTimerAccess(12'h018, 1'b0, 4'h0, 32'd0, "timer read zero wait access");
      Tick();
      CheckEq1(oAxiRvalid, 1'b1, "timer read RVALID response");
      CheckEq32(oAxiRdata, 32'hCAFE_6000, "timer read RDATA");
      CheckEq2(oAxiRresp, LP_AXI_RESP_OKAY, "timer read RRESP");
    end
  endtask

  task automatic RunWaitStateWrite;
    begin
      ResetDut();
      iGpioPready = 1'b0;
      BeginWriteBoth(LP_APB_GPIO_BASE, 4'h3, 32'h0000_BEEF, "wait write");
      Tick();
      CheckGpioAccess(LP_APB_GPIO_BASE[11:0], 1'b1, 4'h3, 32'h0000_BEEF, "wait write access");

      repeat (2) begin
        Tick();
        CheckGpioAccess(LP_APB_GPIO_BASE[11:0], 1'b1, 4'h3, 32'h0000_BEEF, "wait write hold");
        CheckEq1(oAxiBvalid, 1'b0, "wait write holds BVALID low");
      end

      iGpioPready = 1'b1;
      Tick();
      CheckEq1(oAxiBvalid, 1'b1, "wait write BVALID after PREADY");
      CheckEq2(oAxiBresp, LP_AXI_RESP_OKAY, "wait write BRESP OKAY");
    end
  endtask

  task automatic RunWaitStateRead;
    begin
      ResetDut();
      iGpioPready = 1'b0;
      iGpioPrdata = 32'hCAFE_1234;
      BeginRead(LP_APB_GPIO_BASE, "wait read");
      Tick();
      CheckGpioAccess(LP_APB_GPIO_BASE[11:0], 1'b0, 4'h0, 32'd0, "wait read access");

      repeat (2) begin
        Tick();
        CheckGpioAccess(LP_APB_GPIO_BASE[11:0], 1'b0, 4'h0, 32'd0, "wait read hold");
        CheckEq1(oAxiRvalid, 1'b0, "wait read holds RVALID low");
      end

      iGpioPready = 1'b1;
      Tick();
      CheckEq1(oAxiRvalid, 1'b1, "wait read RVALID after PREADY");
      CheckEq32(oAxiRdata, 32'hCAFE_1234, "wait read RDATA");
      CheckEq2(oAxiRresp, LP_AXI_RESP_OKAY, "wait read RRESP OKAY");
    end
  endtask

  task automatic RunAwBeforeW;
    begin
      ResetDut();
      iAxiAwaddr  = LP_APB_GPIO_BASE + 32'h8;
      iAxiAwvalid = 1'b1;
      Tick();
      iAxiAwvalid = 1'b0;
      CheckEq1(oGpioPsel, 1'b0, "AW-before-W no setup before W");
      CheckEq1(oAxiWready, 1'b1, "AW-before-W WREADY remains high");

      iAxiWdata  = 32'h0102_0304;
      iAxiWstrb  = 4'hA;
      iAxiWvalid = 1'b1;
      Tick();
      iAxiWvalid = 1'b0;
      CheckGpioSetup(12'h008, 1'b1, 4'hA, 32'h0102_0304, "AW-before-W");
      FinishWriteFromSetup(LP_AXI_RESP_OKAY, "AW-before-W");
    end
  endtask

  task automatic RunWBeforeAw;
    begin
      ResetDut();
      iAxiWdata  = 32'h1122_3344;
      iAxiWstrb  = 4'h5;
      iAxiWvalid = 1'b1;
      Tick();
      iAxiWvalid = 1'b0;
      CheckEq1(oGpioPsel, 1'b0, "W-before-AW no setup before AW");
      CheckEq1(oAxiAwready, 1'b1, "W-before-AW AWREADY remains high");

      iAxiAwaddr  = LP_APB_GPIO_BASE + 32'hC;
      iAxiAwvalid = 1'b1;
      Tick();
      iAxiAwvalid = 1'b0;
      CheckGpioSetup(12'h00C, 1'b1, 4'h5, 32'h1122_3344, "W-before-AW");
      FinishWriteFromSetup(LP_AXI_RESP_OKAY, "W-before-AW");
    end
  endtask

  task automatic RunDelayedBready;
    begin
      ResetDut();
      iAxiBready = 1'b0;
      BeginWriteBoth(LP_APB_GPIO_BASE, 4'hF, 32'hDEAD_BEEF, "delayed BREADY");
      FinishWriteFromSetup(LP_AXI_RESP_OKAY, "delayed BREADY");

      repeat (2) begin
        Tick();
        CheckEq1(oAxiBvalid, 1'b1, "delayed BREADY holds BVALID");
        CheckEq2(oAxiBresp, LP_AXI_RESP_OKAY, "delayed BREADY holds BRESP");
      end

      iAxiBready = 1'b1;
      Tick();
      CheckEq1(oAxiBvalid, 1'b0, "delayed BREADY handshake clears BVALID");
    end
  endtask

  task automatic RunDelayedRready;
    begin
      ResetDut();
      iAxiRready = 1'b0;
      iGpioPrdata = 32'hFEED_C0DE;
      BeginRead(LP_APB_GPIO_BASE, "delayed RREADY");
      FinishReadFromSetup(32'hFEED_C0DE, LP_AXI_RESP_OKAY, "delayed RREADY");

      repeat (2) begin
        Tick();
        CheckEq1(oAxiRvalid, 1'b1, "delayed RREADY holds RVALID");
        CheckEq32(oAxiRdata, 32'hFEED_C0DE, "delayed RREADY holds RDATA");
        CheckEq2(oAxiRresp, LP_AXI_RESP_OKAY, "delayed RREADY holds RRESP");
      end

      iAxiRready = 1'b1;
      Tick();
      CheckEq1(oAxiRvalid, 1'b0, "delayed RREADY handshake clears RVALID");
    end
  endtask

  task automatic RunPslverrWriteRead;
    begin
      ResetDut();
      iGpioPslverr = 1'b1;
      BeginWriteBoth(LP_APB_GPIO_BASE, 4'hF, 32'h0000_0001, "PSLVERR write");
      FinishWriteFromSetup(LP_AXI_RESP_SLVERR, "PSLVERR write");

      ResetDut();
      iGpioPslverr = 1'b1;
      iGpioPrdata  = 32'hBAD0_0001;
      BeginRead(LP_APB_GPIO_BASE, "PSLVERR read");
      FinishReadFromSetup(32'hBAD0_0001, LP_AXI_RESP_SLVERR, "PSLVERR read");
    end
  endtask

  task automatic RunLocalDecodeMiss;
    begin
      ResetDut();
      iAxiAraddr  = 32'h4000_8000;
      iAxiArvalid = 1'b1;
      Tick();
      iAxiArvalid = 1'b0;
      CheckNoPsel("local miss setup");
      CheckEq1(oPenable, 1'b0, "local miss setup PENABLE");
      CheckEq12(oPaddr, 12'h000, "local miss setup PADDR");

      Tick();
      CheckNoPsel("local miss access");
      CheckEq1(oPenable, 1'b1, "local miss access PENABLE");
      Tick();
      CheckEq1(oAxiRvalid, 1'b1, "local miss RVALID");
      CheckEq32(oAxiRdata, 32'd0, "local miss RDATA zero");
      CheckEq2(oAxiRresp, LP_AXI_RESP_SLVERR, "local miss RRESP SLVERR");
    end
  endtask

  task automatic RunWritePriority;
    begin
      ResetDut();
      iAxiAraddr   = LP_APB_GPIO_BASE + 32'h4;
      iAxiArvalid  = 1'b1;
      iAxiAwaddr   = LP_APB_GPIO_BASE + 32'h10;
      iAxiAwvalid  = 1'b1;
      iAxiWdata    = 32'hABCD_EF01;
      iAxiWstrb    = 4'hF;
      iAxiWvalid   = 1'b1;
      #1;
      CheckEq1(oAxiArready, 1'b0, "write priority blocks ARREADY");
      CheckEq1(oAxiAwready, 1'b1, "write priority accepts AW");
      CheckEq1(oAxiWready, 1'b1, "write priority accepts W");
      Tick();
      iAxiArvalid = 1'b0;
      iAxiAwvalid = 1'b0;
      iAxiWvalid  = 1'b0;
      CheckGpioSetup(12'h010, 1'b1, 4'hF, 32'hABCD_EF01, "write priority");
      FinishWriteFromSetup(LP_AXI_RESP_OKAY, "write priority");
      CheckEq1(oAxiRvalid, 1'b0, "write priority does not produce read response");
    end
  endtask

  initial begin
    iClk = 1'b0;
    ResetDut();
    RunWriteZeroWait();
    RunReadZeroWait();
    RunTimerReadZeroWait();
    RunWaitStateWrite();
    RunWaitStateRead();
    RunAwBeforeW();
    RunWBeforeAw();
    RunDelayedBready();
    RunDelayedRready();
    RunPslverrWriteRead();
    RunLocalDecodeMiss();
    RunWritePriority();
    $display("[PASS] tb_AxiLiteToApbBridge completed");
    $finish;
  end

  initial begin
    repeat (1500) @(posedge iClk);
    $fatal(1, "[FAIL] tb_AxiLiteToApbBridge watchdog expired");
  end

endmodule
