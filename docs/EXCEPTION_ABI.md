# MinitOS K2 — Exception ABI

This document is the contract between startup, the vector table and the
exception handlers. All facts below are implemented in
\`src/boot/start.S\`, \`src/exceptions/vectors.S\` and
\`include/minit/exceptions.h\`, and were demonstrated at runtime in CI
run 5 (see \`docs/evidence/\`).

## Entry point vs reset vector

- The QEMU ELF loader (\`-kernel <file.elf>\`) loads all PT_LOAD segments
  at their program-header addresses and sets the PC to the ELF entry
  point \`_start\` at 0x00010000. It does NOT start at the reset vector.
- The reset slot of the vector table (offset 0x00) nevertheless points
  to \`_start\`, so the table has no dead slot and a reset-style entry
  through 0x00000000 would reach the same startup code.

## Startup contract (state guaranteed before any C code)

\`_start\` guarantees, in order (ARM state throughout):

1. CPSR is forced to SVC mode (0x13) with IRQ and FIQ masked (I=1, F=1).
   The startup does not assume the incoming mode; it never executes
   SVC/undefined instructions to get there. The read-back CPSR value is
   printed at runtime as evidence ("K2 cpsr:").
2. SCTLR (CP15 c1, c0, 0) is read-modify-written with bit 13 (V) cleared
   and read back. The read-back value is stored into the .data variable
   \`minit_sctlr_after_setup\` (sentinel 0xAAAAAAAA proves the store
   happened before .bss clearing). kmain re-checks and prints it.
   With SCTLR.V = 0 the ARM1136 vector base is 0x00000000 (low vectors).
3. Banked stack pointers are installed for IRQ, FIQ, ABT, UND and SVC by
   switching to each mode with I/F still masked. No shared stack is used.
4. .bss is zeroed between __bss_start__ and __bss_end__ (8-byte aligned).
5. sp is 8-byte aligned at every C call boundary (AAPCS requirement).
6. Only then \`kmain\` is called. The MMU and caches remain in their
   reset state (off); K2 makes no other assumption about them.

## Vector table

Linked as its own PT_LOAD segment: p_vaddr = p_paddr = 0x00000000,
filesz = 32 bytes, R+E, not writable. Eight slots, each a branch to a
defined handler or stub (no slot holds data or uncontrolled code):

| Offset | Exception | Entry mode | Handler |
|---|---|---|---|
| 0x00 | Reset | SVC | minit_vec_reset -> _start |
| 0x04 | Undefined Instruction | UND | minit_entry_und |
| 0x08 | SVC | SVC | minit_entry_svc (stub, SVC unused in K2) |
| 0x0C | Prefetch Abort | ABT | minit_entry_pabt (stub) |
| 0x10 | Data Abort | ABT | minit_entry_dabt (full diagnostics) |
| 0x14 | Reserved | UNPREDICTABLE | minit_entry_reserved (stub) |
| 0x18 | IRQ | IRQ | minit_entry_irq (stub, IRQ masked in K2) |
| 0x1C | FIQ | FIQ | minit_entry_fiq (stub, FIQ masked in K2) |

Evidence: docs/evidence/disassembly-vectors.txt shows the eight branch
slots at 0x00000000; docs/evidence/elf-check.log shows the R+E segment
of exactly 32 bytes at vaddr 0.

## Banked stacks

Defined statically in the linker script, printed at runtime and checked
to be 8-byte aligned by tools/verify_elf.py. Addresses below are the
normal profile from CI run 5 (docs/evidence/linker-map.txt); the undef
and data-abort profiles differ by 0x20 because kmain differs in size:

| Mode | Bottom | Top | Size |
|---|---|---|---|
| IRQ | 0x00010dd0 | 0x000111d0 | 0x400 |
| FIQ | 0x000111d0 | 0x000115d0 | 0x400 |
| UND | 0x000115d0 | 0x000119d0 | 0x400 |
| ABT | 0x000119d0 | 0x00011dd0 | 0x400 |
| SVC | 0x00011dd0 | 0x00013dd0 | 0x2000 |

## Exception frame

Built by the EXC_ENTRY wrappers on the banked stack of the entered
mode. The C type is \`minit_exc_frame_t\` (include/minit/exceptions.h)
with compile-time checks: 18 words (72 bytes), 4-byte alignment; sp is
8-byte aligned at the C call because stack tops are 16-byte aligned.

| sp offset | Field | Content |
|---|---|---|
| +0x00 | r[0..12] | r0..r12 exactly as on exception entry |
| +0x34 | lr | banked LR of the entered mode (ARM state) |
| +0x38 | spsr | SPSR of the entered mode |
| +0x3C | vector | vector offset (0x04/0x08/0x0C/0x10/0x14/0x18/0x1C) |
| +0x40 | dfsr | CP15 c5, read only for Data Abort; 0 otherwise |
| +0x44 | dfar | CP15 c6, read only for Data Abort; 0 otherwise |

## Return-address offsets (faulting PC reconstruction)

ARM1136, ARM state:

| Vector | banked LR = | faulting PC = |
|---|---|---|
| UND / SVC / PABT / IRQ / FIQ | faulting PC + 4 | lr - 4 |
| DABT (precise) | faulting PC + 8 | lr - 8 |

The dispatcher prints the reconstructed fault_pc. Cross-checks executed
in CI run 5:
- undef: fault_pc 0x00010634 == the UDF address in disassembly-handlers.txt
- data-abort: fault_pc 0x00010644 == the unaligned LDR address in the
  same disassembly.

## Handler execution model

- The C dispatcher \`minit_exception_dispatch\` runs in the banked
  exception mode of the entered vector, on that mode's own stack. There
  is no mode switch to a panic stack: banked LR/SPSR are already saved
  in the frame, nothing can be lost, and the SPSR stays valid because
  the mode never changes.
- C rules inside the dispatcher: no exceptions are unmasked, no mode
  changes, no access to the SVC stack, no return. K2 is fail-stop:
  after printing the diagnostics and "K2 EXCEPTION CAPTURED" the kernel
  parks in a WFI loop (CP15 c7, c0, 4) forever. No recovery path exists
  in K2 by design.
- The UART prints happen with SCTLR.U/A still set in the data-abort
  scenario; all kernel accesses are aligned by construction, which is
  re-checked implicitly by the prints completing.

## DFSR fault status

The alignment-fault status 0b00001 is accepted in either of two
encodings: the ARM1136 TRM layout (FS[3:1] in bits [3:1], FS[0] in bit
10) and the layout observed on QEMU 8.2.2 arm1136 (FS in bits [4:0]).
The raw DFSR value is always printed. See
docs/ASSUMPTIONS_AND_LIMITATIONS.md for the QEMU deviation.
