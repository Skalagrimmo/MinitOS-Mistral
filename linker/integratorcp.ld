/*
 * MinitOS K2 — link layout for the QEMU integratorcp reference machine.
 *
 * Facts verified against QEMU sources (see docs/K2_ACCEPTANCE.md):
 *   - hw/arm/integratorcp.c: 128 MiB SDRAM at 0x00000000 (aliased again at
 *     0x80000000), PL011 UART0 at 0x16000000.
 *   - hw/arm/boot.c: an ELF passed via -kernel is loaded at its
 *     program-header addresses and the CPU starts at the ELF entry point.
 *
 * K2 layout (TZ MINITOS-K2-TZ, section 3.3):
 *   0x00000000  .vectors   exactly 32 bytes, own R+E PT_LOAD segment
 *   0x00000020..0x0000FFFF reserved (low 64 KiB kept free)
 *   0x00010000  .text/.rodata (R+E segment), ELF entry _start
 *   after that  .data/.bss/.stacks (R+W segment)
 *
 * RAM is pinned to 128 MiB by scripts/run-qemu.sh and scripts/k2-harness.sh;
 * keep those files in sync with this script.
 */

ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 128M
}

PHDRS
{
    vectors PT_LOAD FLAGS(5);   /* R E */
    text    PT_LOAD FLAGS(5);   /* R E */
    data    PT_LOAD FLAGS(6);   /* R W */
}

SECTIONS
{
    .vectors 0x00000000 :
    {
        KEEP(*(.vectors))
    } > RAM :vectors

    .text 0x00010000 :
    {
        KEEP(*(.text.boot))
        *(.text*)
    } > RAM :text

    .rodata :
    {
        *(.rodata*)
    } > RAM :text

    .data :
    {
        *(.data*)
    } > RAM :data

    .bss (NOLOAD) :
    {
        . = ALIGN(8);
        __bss_start__ = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(8);
        __bss_end__ = .;
    } > RAM :data

    /* Banked exception stacks (TZ section 4.2). Sizes are static, the
       region is 16-byte aligned and every stack top is 8-byte aligned for
       the AAPCS C ABI. Boundaries are printed at runtime for evidence. */
    .stacks (NOLOAD) :
    {
        . = ALIGN(16);
        __irq_stack_bottom__ = .;
        . += 0x400;
        __irq_stack_top__ = .;
        __fiq_stack_bottom__ = .;
        . += 0x400;
        __fiq_stack_top__ = .;
        __und_stack_bottom__ = .;
        . += 0x400;
        __und_stack_top__ = .;
        __abt_stack_bottom__ = .;
        . += 0x400;
        __abt_stack_top__ = .;
        __svc_stack_bottom__ = .;
        . += 0x2000;
        __svc_stack_top__ = .;
    } > RAM :data

    ASSERT(SIZEOF(.vectors) == 32, "K2: vector table must be exactly 32 bytes")
    ASSERT(SIZEOF(.stacks) == 0x3000, "K2: unexpected stacks section size")

    /DISCARD/ :
    {
        *(.ARM.exidx*)
        *(.ARM.extab*)
        *(.ARM.attributes)
        *(.comment)
    }
}
