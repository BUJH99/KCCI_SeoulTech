MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
  DMEM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.text.start))
    *(.text .text.*)
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
    . = ALIGN(4);
  } > IMEM

  .bss (NOLOAD) : ALIGN(4)
  {
    __bss_start = .;
    *(.bss .bss.*)
    *(.sbss .sbss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > DMEM

  __stack_top = ORIGIN(DMEM) + LENGTH(DMEM) - 4;

  /DISCARD/ :
  {
    *(.comment)
    *(.note*)
    *(.eh_frame*)
    *(.gnu*)
    *(.riscv.attributes)
  }
}
