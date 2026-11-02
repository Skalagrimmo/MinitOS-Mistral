/*
 * MinitOS K2 — startup for QEMU integratorcp (ARM1136).
 *
 * Entry contract (full version in docs/EXCEPTION_ABI.md):
 *   - QEMU loads the ELF at its program-header addresses and jumps to the
 *     ELF entry point (_start) in ARM state. The reset vector is NOT the
 *     actual entry path under this loader.
 *   - The CPU is assumed to be in a privileged state; we force SVC mode
 *     with IRQ/FIQ masked regardless of the incoming CPSR.
 *
 * Before any C code runs this code must have (TZ section 4.1):
 *   1. privileged SVC mode, IRQ/FIQ masked;
 *   2. SCTLR.V = 0 (low vectors at 0x00000000), read-modify-write with
 *      read-back, result stored into minit_sctlr_after_setup (.data);
 *   3. banked stack pointers for SVC/UND/ABT/IRQ/FIQ;
 *   4. .bss zeroed;
 *   5. 8-byte aligned sp at the C boundary.
 */

.syntax unified
.cpu arm1136jf-s
.arm

.equ MODE_FIQ, 0x11
.equ MODE_IRQ, 0x12
.equ MODE_SVC, 0x13
.equ MODE_ABT, 0x17
.equ MODE_UND, 0x1B
.equ CPSR_MASKED, 0xC0          /* I | F */

.section .text.boot, "ax", %progbits
.global _start
.type _start, %function

_start:
    /* 1. Defined privileged state: SVC, IRQ/FIQ masked. */
    mrs     r0, cpsr
    bic     r0, r0, #0x1F
    orr     r0, r0, #MODE_SVC
    orr     r0, r0, #CPSR_MASKED
    msr     cpsr_c, r0

    /* 2. Low vectors: SCTLR.V = 0, read-modify-write with read-back.
          Stored into .data (survives .bss clearing below). */
    mrc     p15, 0, r0, c1, c0, 0
    bic     r0, r0, #(1 << 13)
    mcr     p15, 0, r0, c1, c0, 0
    mrc     p15, 0, r0, c1, c0, 0
    ldr     r1, =minit_sctlr_after_setup
    str     r0, [r1]

    /* 3. Banked stack pointers for all modes with handlers (TZ 4.2). */
    mov     r0, #MODE_IRQ
    orr     r0, r0, #CPSR_MASKED
    msr     cpsr_c, r0
    ldr     sp, =__irq_stack_top__

    mov     r0, #MODE_FIQ
    orr     r0, r0, #CPSR_MASKED
    msr     cpsr_c, r0
    ldr     sp, =__fiq_stack_top__

    mov     r0, #MODE_ABT
    orr     r0, r0, #CPSR_MASKED
    msr     cpsr_c, r0
    ldr     sp, =__abt_stack_top__

    mov     r0, #MODE_UND
    orr     r0, r0, #CPSR_MASKED
    msr     cpsr_c, r0
    ldr     sp, =__und_stack_top__

    mov     r0, #MODE_SVC
    orr     r0, r0, #CPSR_MASKED
    msr     cpsr_c, r0
    ldr     sp, =__svc_stack_top__

    /* 4. Zero .bss so C statics start deterministic. */
    ldr     r0, =__bss_start__
    ldr     r1, =__bss_end__
    mov     r2, #0
1:
    cmp     r0, r1
    strlo   r2, [r0], #4
    blo     1b

    /* 5. Enter the kernel. */
    bl      kmain
2:
    b       2b

.size _start, . - _start
