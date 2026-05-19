`timescale 1ns / 1ps

module tb_InstrBusMux;
  import rv32i_pkg::*;

  logic [31:0] iInstrAddr;
  logic [31:0] iBootInstr;
  logic [31:0] iProgramInstr;
  logic [31:0] oInstr;

  InstrBusMux dut (
    .iInstrAddr(iInstrAddr),
    .iBootInstr(iBootInstr),
    .iProgramInstr(iProgramInstr),
    .oInstr(oInstr)
  );

  initial begin
    iBootInstr    = 32'h1111_1111;
    iProgramInstr = 32'h2222_2222;

    iInstrAddr = LP_BOOT_ROM_BASE;
    #1;
    if (oInstr !== iBootInstr) begin
      $fatal(1, "[FAIL] boot range did not select BootRom");
    end

    iInstrAddr = LP_PROGRAM_RAM_BASE;
    #1;
    if (oInstr !== iProgramInstr) begin
      $fatal(1, "[FAIL] program range did not select ProgramRam");
    end

    iInstrAddr = 32'h0001_0000;
    #1;
    if (oInstr !== 32'h0000_0013) begin
      $fatal(1, "[FAIL] unmapped instruction did not return NOP");
    end

    $display("[PASS] tb_InstrBusMux");
    $finish;
  end
endmodule
