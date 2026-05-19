ENTRY(_start)

PHDRS
{
  text PT_LOAD FLAGS(5);
}

MEMORY
{
  BOOT_ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x1000
  DATA_RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x0400
}

SECTIONS
{
  .text :
  {
    KEEP(*(.text.startup .text.startup.*))
    *(.text .text.*)
    *(.rodata .rodata.*)
    . = ALIGN(4);
  } > BOOT_ROM :text

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
