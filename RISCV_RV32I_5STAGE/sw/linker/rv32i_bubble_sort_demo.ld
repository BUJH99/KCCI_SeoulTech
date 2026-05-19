ENTRY(_start)

PHDRS
{
  text PT_LOAD FLAGS(5);
}

MEMORY
{
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1K
}

SECTIONS
{
  .text :
  {
    KEEP(*(.text.startup .text.startup.*))
    *(.text .text.*)
    *(.rodata .rodata.*)
    . = ALIGN(4);
  } > ROM :text

  .data (NOLOAD) :
  {
    __data_start = .;
    *(.sdata .sdata.*)
    *(.data .data.*)
    . = ALIGN(4);
    __data_end = .;
  } > RAM :NONE

  .bss (NOLOAD) :
  {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM :NONE

  __stack_top = ORIGIN(RAM) + LENGTH(RAM);

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
