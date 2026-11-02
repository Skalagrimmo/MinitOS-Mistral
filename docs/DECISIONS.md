# MinitOS K1 — Decision Log (ADR)

All decisions were taken on 2026-11-02 for the K1 stage. Status: Accepted
unless noted otherwise. K0 was treated strictly as an input artifact to
analyze; no K0 source file was reused (ADR-001).

## ADR-001: Independent implementation, K0 analyzed only

Context: K0 (Clang 17, arm-none-eabi, entry 0x00010000, no I/O) proved the
toolchain; its build log, disassembly, ELF and marker were reviewed.
Decision: write the K1 structure, linker script and drivers from scratch,
basing every hardware claim on QEMU sources, not on K0's layout.
Consequences: K0's qemu-integratorcp.ld was not read; the K1 layout is
derived from integratorcp.c/boot.c facts and may differ from K0's.

## ADR-002: Image base 0x00010000

Low 64 KiB of SDRAM (which starts at 0x0 on integratorcp) stay free for
exception vectors in K2+. The base also matches what QEMU's Linux loader
would use on this board (loader_start 0x0 + 0x10000), so the choice is
conventional rather than arbitrary. Not a Galaxy Gio address in any way.

## ADR-003: RAM pinned to 64 MiB; stack after the image

scripts/run-qemu.sh passes -m 64M and linker/integratorcp.ld describes the
same 64 MiB (minus the low 64 KiB). The 16 KiB initial stack is placed
directly after the image for predictable, inspectable memory use; moving it
to the top of RAM is deferred to the memory-management stage.

## ADR-004: UART0 = PL011 at 0x16000000, 115200 8N1, 24 MHz assumed

UART0 base verified in QEMU hw/arm/integratorcp.c (pl011_create(0x16000000,
...)). Baud divisors (IBRD=13, FBRD=1) assume a 24 MHz reference clock —
the integratorcp CM_REFCNT runs at 24 MHz in QEMU. QEMU's PL011 ignores
the programmed baud rate, so this assumption cannot break the K1 run; it is
recorded because it will matter on real hardware.

## ADR-005: Full PL011 init sequence is mandatory

Verified in QEMU hw/char/pl011.c: pl011_write_txdata drops data-register
writes unless CR.UARTEN is set. A "just write to DR" driver would print
nothing on current QEMU. The driver therefore disables, clears interrupts,
sets divisors, sets LCR_H, unmasks nothing, then enables UART/TX/RX.

## ADR-006: Polled TX only, no interrupt controller setup in K1

K1 has no IRQ handling, so IMSC is left at 0 and no PIC/timer is touched.
RX is not read. This keeps the first executable stage minimal.

## ADR-007: Entry contract — QEMU ELF path

Verified in hw/arm/boot.c: "raw images are linux kernels, and ELF images
are not"; arm_load_elf loads the ELF at its program-header addresses,
entry = elf_entry, and cpu_set_pc(entry) on reset. The kernel therefore
assumes nothing about r0-r2 (no ATAGS/boot protocol) and starts entirely
from the ELF entry point.

## ADR-008: Idle via ARMv6 cp15 WFI

arm1136jf-s is ARMv6: the ARMv7 'wfi' mnemonic is not available. The idle
loop uses the coprocessor form (mcr p15, 0, r0, c7, c0, 4). With no
interrupt sources enabled, the CPU parks; the banner has already been
flushed to stdio by then.

## ADR-009: Runtime proof beyond a static string

The banner alone is a static string that could sit in the image; the
kernel also prints two link-time constants (image base, stack top) as hex
at runtime. Seeing values that match linker/integratorcp.ld on the serial
line proves that executing code produced the output.

## ADR-010: Reproducibility posture

lld, --build-id=none, fixed -O2, no timestamps. tools/verify_elf.py prints
SHA-256 of the ELF and .bin so two builds with the same toolchain can be
compared byte-for-byte. Pinning the compiler version remains the user's
responsibility (make info records versions).

## ADR-011: No vector table at 0x0 in K1

If any exception occurs before K2, the CPU jumps to 0x0, which is zeroed
RAM — undefined behaviour and an accepted K1 limitation, documented in
docs/K1_REPORT.md.

## ADR-012: platform.h as the single hardware boundary

All hardware addresses live in include/minit/platform.h. The future
MSM7227 (Galaxy Gio) port must replace platform.h and the boot path, not
the kernel or the PL011 logic.

## ADR-013: BSS zeroed in assembly before any C

start.S zeroes .bss before calling kmain, so C statics are deterministic.
The loop handles an empty .bss (as in K1) correctly.

## ADR-014: -kernel gets the ELF; the flat .bin is a by-product

QEMU's direct-ELF path (ADR-007) is used for execution; llvm-objcopy also
produces a flat binary because later stages (flash tooling, real boards)
will need it. Nothing loads the .bin in K1.
