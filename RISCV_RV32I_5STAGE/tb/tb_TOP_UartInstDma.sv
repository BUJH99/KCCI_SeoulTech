/*
[TB_INFO_START]
Name: tb_TOP_UartInstDma
Target: TOP
Role: Integration smoke test for UART packet loading into ProgramRam
Scenario:
  - Boots from BootRom, sends one RAXI packet over serial UART, and checks ProgramRam write + DONE status
[TB_INFO_END]
*/

`timescale 1ns / 1ps

module TbTop;
  import rv32i_pkg::*;

  localparam int unsigned LP_CLK_HZ = 1_843_200;
  localparam int unsigned LP_UART_BAUD = 115_200;
  localparam int unsigned LP_UART_BIT_CYCLES = LP_CLK_HZ / LP_UART_BAUD;
  localparam int unsigned LP_GPIO_WIDTH = 8;

  logic iClk;
  logic iRst;
  logic iUartRx;
  logic [LP_GPIO_WIDTH-1:0] iGpioIn;
  logic iSpiMiso;
  tri1  ioI2cScl;
  tri1  ioI2cSda;
  logic oUartTx;
  logic [LP_GPIO_WIDTH-1:0] oGpioOut;
  logic [LP_GPIO_WIDTH-1:0] oGpioOe;
  logic oSpiSclk;
  logic oSpiMosi;
  logic oSpiCsN;
  logic [6:0] oSeg;
  logic oDp;
  logic [3:0] oDigitSel;
  logic oTimingProbe;

  TOP #(
    .P_CLK_HZ(LP_CLK_HZ),
    .P_SYS_CLK_DIVIDE(1),
    .P_UART_BAUD(LP_UART_BAUD),
    .P_GPIO_WIDTH(LP_GPIO_WIDTH)
  ) dut (
    .iClk(iClk),
    .iRst(iRst),
    .iUartRx(iUartRx),
    .iGpioIn(iGpioIn),
    .iSpiMiso(iSpiMiso),
    .ioI2cScl(ioI2cScl),
    .ioI2cSda(ioI2cSda),
    .oUartTx(oUartTx),
    .oGpioOut(oGpioOut),
    .oGpioOe(oGpioOe),
    .oSpiSclk(oSpiSclk),
    .oSpiMosi(oSpiMosi),
    .oSpiCsN(oSpiCsN),
    .oSeg(oSeg),
    .oDp(oDp),
    .oDigitSel(oDigitSel),
    .oTimingProbe(oTimingProbe)
  );

  always #5 iClk = ~iClk;

  task automatic WaitBit;
    begin
      repeat (LP_UART_BIT_CYCLES) @(posedge dut.SysClk);
    end
  endtask

  task automatic SendUartByte(input logic [7:0] data);
    int bitIdx;
    begin
      iUartRx <= 1'b0;
      WaitBit();
      for (bitIdx = 0; bitIdx < 8; bitIdx = bitIdx + 1) begin
        iUartRx <= data[bitIdx];
        WaitBit();
      end
      iUartRx <= 1'b1;
      WaitBit();
    end
  endtask

  task automatic SendU32(input logic [31:0] data);
    begin
      SendUartByte(data[7:0]);
      SendUartByte(data[15:8]);
      SendUartByte(data[23:16]);
      SendUartByte(data[31:24]);
    end
  endtask

  initial begin
    iClk     = 1'b0;
    iRst    = 1'b1;
    iUartRx  = 1'b1;
    iGpioIn  = '0;
    iSpiMiso = 1'b0;

    repeat (20) @(posedge iClk);
    iRst <= 1'b0;
    wait (dut.SysRst === 1'b0);
    wait (dut.InstDmaCtrlArm === 1'b1);
    repeat (32) @(posedge dut.SysClk);

    SendUartByte("R");
    SendUartByte("A");
    SendUartByte("X");
    SendUartByte("I");
    SendU32(32'h0000_1000);
    SendU32(32'd4);
    SendU32(32'h0000_1000);
    SendU32(32'h0000_006F);
    SendUartByte(8'h6F);
    SendUartByte(8'h00);
    SendUartByte(8'h00);
    SendUartByte(8'h00);

    repeat (2000) @(posedge dut.SysClk);

    if (dut.uInstrFetchMemory.uProgramRam.gen_direct_ram.MemRam[0] !== 32'h0000_006F) begin
      $fatal(1, "[FAIL] ProgramRam[0] was not loaded: mem=0x%08x done=%0b err=%0b code=0x%02x state=%0d",
             dut.uInstrFetchMemory.uProgramRam.gen_direct_ram.MemRam[0], dut.InstDmaDone, dut.InstDmaErr,
             dut.InstDmaErrCode, dut.uInstDma.uInstDmaCtrl.state);
    end
    if (dut.uInstDma.oStatusDone !== 1'b1) begin
      $fatal(1, "[FAIL] InstDma DONE was not set: mem=0x%08x done=%0b err=%0b code=0x%02x state=%0d bytes=%0d entry=0x%08x pc=0x%08x arm=%0b clear=%0b mode=%0d",
             dut.uInstrFetchMemory.uProgramRam.gen_direct_ram.MemRam[0], dut.InstDmaDone, dut.InstDmaErr,
             dut.InstDmaErrCode, dut.uInstDma.uInstDmaCtrl.state,
             dut.uInstDma.uInstDmaCtrl.payloadByteIndex,
             dut.uInstDma.uInstDmaCtrl.entryAddr, dut.uRv32iCore.Pc,
             dut.InstDmaCtrlArm, dut.InstDmaCtrlClearErr, dut.UartMode);
    end

    $display("[PASS] TOP UART InstDma integration completed");
    $finish;
  end

  initial begin : watchdog
    repeat (20000) @(posedge iClk);
    $fatal(1, "[FAIL] tb_TOP_UartInstDma watchdog");
  end
endmodule
