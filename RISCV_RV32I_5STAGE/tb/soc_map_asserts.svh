`ifndef SOC_MAP_ASSERTS_SVH
`define SOC_MAP_ASSERTS_SVH

initial begin : soc_map_static_asserts
  if (rv32i_pkg::LP_BOOT_ROM_BASE != 32'h0000_0000) begin
    $fatal(1, "[FAIL] BootRom base mismatch");
  end
  if (rv32i_pkg::LP_PROGRAM_RAM_BASE != 32'h0000_1000) begin
    $fatal(1, "[FAIL] ProgramRam base mismatch");
  end
  if (rv32i_pkg::LP_APB_INST_DMA_BASE != 32'h4000_7000) begin
    $fatal(1, "[FAIL] InstDma APB base mismatch");
  end
end

`endif
