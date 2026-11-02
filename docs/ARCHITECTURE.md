# MinitOS K2 — Architecture

## Boot flow

1. QEMU (integratorcp, ARM1136, 128 MiB) loads the ELF passed with
   -kernel at its program-header addresses and sets the PC to the ELF
   entry point _start (src/boot/start.S), ARM state.
2. _start forces SVC mode with IRQ/FIQ masked, clears SCTLR.V with
   read-modify-write and read-back (stored to minit_sctlr_after_setup),
   installs banked stacks for IRQ/FIQ/ABT/UND/SVC, zeroes .bss, then
   calls kmain.
3. kmain initializes UART0 (PL011 at 0x16000000), prints the executed
   startup diagnostics (SCTLR, vector base, CPSR, stack boundaries) and
   dispatches to the scenario compiled in (normal / undef / data-abort).

## Exception flow (the K2 addition)

- Any ARMv6 exception enters at 0x00000000 + offset (low vectors,
  SCTLR.V = 0). The .vectors segment contains eight branches, one per
  vector slot, to defined handlers or stubs.
- Each EXC_ENTRY wrapper builds the 18-word minit_exc_frame_t on the
  entered mode's banked stack (r0-r12, banked LR, SPSR, vector offset;
  DFSR/DFAR via CP15 c5/c6 for Data Abort) and tail-calls the C
  dispatcher with the frame pointer.
- minit_exception_dispatch prints the diagnostics contract (exception
  type, vector, mode, lr, spsr, dfsr/dfar, reconstructed fault_pc),
  executes the runtime assertions for the alignment test, prints
  "K2 EXCEPTION CAPTURED" and parks in a WFI halt. K2 never returns from
  an exception.
- The exception ABI (modes, stacks, frame, LR offsets) is the contract
  documented in docs/EXCEPTION_ABI.md.

## Memory layout (linker/integratorcp.ld)

| Region | Address | Notes |
|---|---|---|
| .vectors | 0x00000000, 32 bytes | Own R+E PT_LOAD segment, 8 branch slots. |
| Reserved | 0x00000020-0x0000FFFF | Low 64 KiB kept free. |
| .text/.rodata | from 0x00010000 | R+E segment; ELF entry _start at 0x00010000. |
| .data | after .rodata | e.g. minit_test_area, minit_sctlr_after_setup. |
| .bss (NOLOAD) | after .data | 8-byte aligned, zeroed by _start. |
| .stacks (NOLOAD) | after .bss | IRQ/FIQ/UND/ABT 0x400 each, SVC 0x2000. |
| RAM size | 128 MiB | Pinned by -m 128M in scripts/run-qemu.sh and scripts/k2-harness.sh. |

SDRAM starts at 0x00000000 on integratorcp (aliased again at 0x80000000).

## Module boundaries

| Unit | Responsibility |
|---|---|
| include/minit/platform.h | The only place with hardware addresses (QEMU integratorcp). |
| include/minit/exceptions.h | Exception ABI: vector offsets, frame type, dispatcher contract. |
| include/minit/tests.h | Scenario ids and test contracts. |
| src/boot/start.S | Mode, SCTLR.V, banked stacks, BSS clear; no C before this. |
| src/exceptions/vectors.S | Vector table and frame-building entry wrappers. |
| src/exceptions/handlers.c | Fail-stop C dispatcher and fault diagnostics. |
| src/kernel/main.c | Kernel policy, executed startup diagnostics, scenario dispatch. |
| src/tests/faults.S | Raw fault triggers (UDF, unaligned LDR) as real instructions. |
| src/tests/scenarios.c | Test orchestration: SCTLR RMW + read-back, prints. |
| src/drivers/pl011.c | Generic PL011 logic; base address from platform.h. |
| linker/integratorcp.ld | Layout contract incl. the vectors segment and stacks. |
| tools/verify_elf.py | Executed static checks of the artifacts. |
| scripts/k2-harness.sh | Marker-terminated QEMU runtime harness. |

Rule for the future MSM7227 (Galaxy Gio) port: kernel policy, exception
frame and PL011 logic must not change; the port replaces platform.h, the
linker script and the boot path, because that board's memory map, vector
base and boot protocol are different and still unverified.

## Verification model

- Static: tools/verify_elf.py (ELF class, endianness, machine, ET_EXEC,
  EABI5, entry inside PT_LOAD, vector segment with 8 branch slots,
  symbols, stack-top alignment, no undefined symbols, banner/exception
  strings, UDF bytes, SHA-256).
- Runtime: each scenario boots in its own QEMU process; the harness
  terminates QEMU only after the scenario's terminal UART marker, and
  CI greps per-scenario required lines (vector offset, mode, DFSR/DFAR
  assertions). Executed evidence is committed in docs/evidence/.

## K2 limitations (intentional)

- Fail-stop exception handling; no recovery, no MMU, no interrupt
  controller, no scheduler (see docs/ASSUMPTIONS_AND_LIMITATIONS.md).
