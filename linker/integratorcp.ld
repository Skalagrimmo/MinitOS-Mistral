/*
 * MinitOS K1 — link layout for the QEMU integratorcp reference machine.
 *
 * Facts verified against QEMU sources (not inherited from K0):
 *   - hw/arm/integratorcp.c: SDRAM starts at 0x00000000 (aliased again at
 *     0x80000000); UART0 is a PL011 mapped at 0x16000000.
 *   - hw/arm/boot.c: an ELF passed via -kernel is loaded at its
 *     program-header addresses and the CPU starts at the ELF entry point.
 *
 * The image base is 0x00010000 so the low 64 KiB stay free for future
 * exception vectors (K2+). RAM is pinned to 64 MiB by scripts/run-qemu.sh;
 * this region description must stay in sync with that script.
 */

ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 64M - 0x10000
}

SECTIONS
{
    .text :
    {
        __image_start__ = .;
        KEEP(*(.text.boot))
        *(.text*)
    } > RAM

    .rodata :
    {
        *(.rodata*)
    } > RAM

    .data :
    {
        *(.data*)
    } > RAM

    .bss (NOLOAD) :
    {
        . = ALIGN(8);
        __bss_start__ = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(8);
        __bss_end__ = .;
    } > RAM

    . = ALIGN(16);
    __image_end__ = .;

    /* 16 KiB initial stack, placed right after the image (ADR-003). */
    .stack (NOLOAD) :
    {
        . = ALIGN(16);
        . += 0x4000;
        __stack_top__ = .;
    } > RAM

    ASSERT(__stack_top__ <= ORIGIN(RAM) + LENGTH(RAM), "K1 RAM region overflow")

    /DISCARD/ :
    {
        *(.ARM.exidx*)
        *(.ARM.extab*)
        *(.ARM.attributes)
        *(.comment)
    }
}
