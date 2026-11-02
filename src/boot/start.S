/*
 * MinitOS K1 — entry point for the QEMU integratorcp machine (ARM1136).
 *
 * Entry contract (K1, verified against hw/arm/boot.c):
 *   - QEMU loads this ELF at its program-header addresses and jumps to
 *     the ELF entry point (_start) with the CPU in ARM state.
 *   - Nothing is assumed about r0-r2 or sp; the CPU is assumed to come
 *     out of reset in a privileged mode with I/F interrupts masked
 *     (standard ARM reset state; see docs/K1_REPORT.md, assumptions).
 *   - No C code runs before the stack is set and .bss is zeroed.
 */

.syntax unified
.cpu arm1136jf-s
.arm

.section .text.boot, "ax", %progbits
.global _start
.type _start, %function

_start:
    /* Establish a private stack before any C code runs. */
    ldr     sp, =__stack_top__

    /* Zero .bss so C statics start deterministic (ADR-013). */
    ldr     r0, =__bss_start__
    ldr     r1, =__bss_end__
    mov     r2, #0
1:
    cmp     r0, r1
    strlo   r2, [r0], #4
    blo     1b

    /* Enter the kernel proper. */
    bl      kmain

    /* kmain must never return; trap here if it ever does. */
2:
    b       2b

.size _start, . - _start
