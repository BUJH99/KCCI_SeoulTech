ENTRY(_start)

PHDRS
{
  text PT_LOAD FLAGS(5);
}

MEMORY
{
  PROGRAM_RAM (rx)  : ORIGIN = 0x00001000, LENGTH = 0x0000F000
  DATA_RAM    (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00000400
}

SECTIONS
{
  .text :
  {
    KEEP(*(.text.startup .text.startup.*))
    *(.text .text.*)
    . = ALIGN(4);
  } > PROGRAM_RAM :text

  .rodata :
  {
    *(.rodata .rodata.*)
    . = ALIGN(4);
  } > PROGRAM_RAM :text

  .data (NOLOAD) :
  {
    __data_start = .;
    *(.sdata .sdata.*)
    *(.data .data.*)
    . = ALIGN(4);
    __data_end = .;
  } > DATA_RAM :NONE

  .bss (NOLOAD) :
  {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > DATA_RAM :NONE

  __stack_top = ORIGIN(DATA_RAM) + LENGTH(DATA_RAM);

  /DISCARD/ :
  {
    *(.comment)
    *(.riscv.attributes)
    *(.eh_frame .eh_frame.*)
    *(.eh_frame_hdr)
    *(.interp)
    *(.note .note.*)
    *(.dynamic)
    *(.dynsym)
    *(.dynstr)
    *(.gnu.hash)
    *(.got .got.*)
    *(.plt .plt.*)
  }
}
