# MinitOS K1 — Architecture

## Boot flow

1. QEMU (integratorcp, ARM1136) loads the ELF image passed with -kernel at
   its program-header addresses and sets the PC to the ELF entry point
   (verified in QEMU hw/arm/boot.c: an ELF image is not treated as Linux).
2. CPU starts at _start (src/boot/start.S) in ARM state.
3. _start sets sp to __stack_top__, zeroes .bss, calls kmain.
4. kmain (src/kernel/main.c) initializes UART0, prints the banner and
   link-time constants as hex, then parks the CPU in a WFI loop.

## Memory layout (linker/integratorcp.ld)

| Region | Address | Notes |
|---|---|---|
| Low memory | 0x00000000-0x0000FFFF | Reserved for exception vectors (K2+). |
| Image (.text/.rodata/.data) | from 0x00010000 | Matches ELF entry. |
| .bss (NOLOAD) | after .data | Zeroed by _start before C code runs. |
| .stack (NOLOAD) | 16 KiB after the image | __stack_top__ = top of the stack block. |
| RAM size | 64 MiB | Pinned by -m 64M in scripts/run-qemu.sh; linker region must stay in sync. |

SDRAM starts at 0x00000000 on integratorcp and is also aliased at 0x80000000.

## Module boundaries

| Unit | Responsibility |
|---|---|
| include/minit/platform.h | The only place with hardware addresses (K1: QEMU integratorcp). |
| include/minit/uart.h | UART API contract. |
| include/minit/kernel.h | Kernel entry contract. |
| src/boot/start.S | Entry, stack setup, BSS clear; no C runs before these are done. |
| src/drivers/pl011.c | Generic PL011 logic; the base address comes from platform.h. |
| src/kernel/main.c | Kernel policy; talks only to the uart.h API. |

Rule for the future MSM7227 (Galaxy Gio) port: kernel/main.c and the PL011
logic must not change; the port replaces platform.h and adds its own boot
path, because that board's memory map and boot protocol are different and
still unverified.

## K1 limitations (intentional)

- No interrupt controller setup; no exception vector table at 0x0
  (any exception is fatal — documented in docs/K1_REPORT.md).
- Single core, single thread of execution; no scheduler.
- UART: polled TX only; RX is not handled in K1.
- No MMU, no physical memory manager yet.

## Verification model

tools/verify_elf.py checks structural facts of the artifact: ELF class,
endianness, machine, ELF type, entry equals the expected address and lies
inside a PT_LOAD segment, required symbols exist, the banner string is
embedded, and the SHA-256 of the image is printed (for reproducible-build
comparison). It makes no claim about runtime behaviour; runtime proof is
the UART output produced via scripts/run-qemu.sh.
