OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS {
    . = 0;
    .text : { *(.text.start) *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }
    .data : { *(.data .data.*) }
    .bss : { *(.bss .bss.*) *(COMMON) }
    ASSERT(. < 0x1f000, "Firmware overlaps reserved stack")
}
