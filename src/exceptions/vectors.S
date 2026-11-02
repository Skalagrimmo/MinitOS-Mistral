/*
 * MinitOS K2 — exception vector table and entry wrappers (ARM1136).
 *
 * The table lives in its own section .vectors, linked at 0x00000000 as a
 * separate R+E PT_LOAD segment (see linker/integratorcp.ld). SCTLR.V is
 * cleared by src/boot/start.S, so the CPU fetches exception entry from
 * exactly these 32 bytes (TZ sections 3.2-3.4).
 *
 * The QEMU ELF loader starts execution at the ELF entry point (_start),
 * NOT at the reset vector — documented in docs/EXCEPTION_ABI.md. The
 * reset slot still points at _start so the table has no dead slot.
 */

.syntax unified
.cpu arm1136jf-s
.arm

.section .vectors, "ax", %progbits
.global _vector_table
.type _vector_table, %object
_vector_table:
    b   minit_vec_reset         @ 0x00 RESET      -> SVC
    b   minit_entry_und         @ 0x04 UNDEFINED  -> UND
    b   minit_entry_svc         @ 0x08 SVC        -> SVC
    b   minit_entry_pabt        @ 0x0C PABT       -> ABT
    b   minit_entry_dabt        @ 0x10 DABT       -> ABT
    b   minit_entry_reserved    @ 0x14 RESERVED
    b   minit_entry_irq         @ 0x18 IRQ        -> IRQ
    b   minit_entry_fiq         @ 0x1C FIQ        -> FIQ
.size _vector_table, . - _vector_table

.section .text.exceptions, "ax", %progbits
.global minit_vec_reset
.type minit_vec_reset, %function
minit_vec_reset:
    b   _start

/*
 * EXC_ENTRY <name>, <vector offset>, <read_dfsr>
 *
 * Builds a minit_exc_frame_t on the banked stack of the entered mode:
 *   [sp+0x00..0x30] r0..r12 as on entry
 *   [sp+0x34] banked LR of the mode
 *   [sp+0x38] SPSR of the mode
 *   [sp+0x3C] vector offset
 *   [sp+0x40] DFSR (read_dfsr != 0, i.e. Data Abort only; else 0)
 *   [sp+0x44] DFAR (same condition; else 0)
 * and tail-calls the C dispatcher with the frame pointer in r0.
 * 72 bytes on a 16-byte-aligned stack top keep sp 8-byte aligned at the
 * call. The dispatcher never returns (K2 is fail-stop).
 */
.macro EXC_ENTRY name, vec, read_dfsr
\name:
    push    {r0-r12}
    sub     sp, sp, #(5*4)
    mov     r0, lr
    mov     r1, #\vec
    str     r0, [sp, #(13*4)]
    mrs     r0, spsr
    str     r0, [sp, #(14*4)]
    str     r1, [sp, #(15*4)]
.if \read_dfsr
    mrc     p15, 0, r0, c5, c0, 0
    str     r0, [sp, #(16*4)]
    mrc     p15, 0, r0, c6, c0, 0
    str     r0, [sp, #(17*4)]
.else
    mov     r0, #0
    str     r0, [sp, #(16*4)]
    str     r0, [sp, #(17*4)]
.endif
    mov     r0, sp
    b       minit_exception_dispatch
.endm

.global minit_entry_und
.global minit_entry_svc
.global minit_entry_pabt
.global minit_entry_dabt
.global minit_entry_reserved
.global minit_entry_irq
.global minit_entry_fiq

EXC_ENTRY minit_entry_und,      0x04, 0
EXC_ENTRY minit_entry_svc,      0x08, 0
EXC_ENTRY minit_entry_pabt,     0x0C, 0
EXC_ENTRY minit_entry_dabt,     0x10, 1
EXC_ENTRY minit_entry_reserved, 0x14, 0
EXC_ENTRY minit_entry_irq,      0x18, 0
EXC_ENTRY minit_entry_fiq,      0x1C, 0
