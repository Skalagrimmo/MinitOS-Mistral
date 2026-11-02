# MinitOS K1 — Acceptance Report

Date: 2026-11-02. Status: ACCEPTED.

All acceptance criteria were executed and passed in CI (workflow run #5,
commit 43337b2c on main). Raw evidence for every step lives in the branch
ci/evidence/5 (files ci/5/*.log). Nothing in this report is marked PASS
without a run behind it.

## 1. Analysis of the received K0

Reviewed artifacts: build log, disassembly, SHA256SUMS, verify_elf.py,
main.c, README, and (from the project library) entry.S and Makefile.

Findings:
- K0 ELF32 LE ARM, entry 0x00010000, _start at 0x10000, kernel_main at
  0x10030, marker "MNT0" (0x4D4E5430) at 0x1005c. Consistent with its
  build log; nothing suspicious.
- _start clears [0x10060, 0x10060) — an empty .bss — then jumps to
  kernel_main, which loops forever. No I/O, as documented.
- K0's own docs state that 0x00010000 is a reference address, not a Gio
  address. K1 keeps the same base for different, documented reasons
  (ADR-002), still with no claim about the phone.
- K0's verify_elf.py checks structure only; K1 extends this with entry
  equality, entry-in-PT_LOAD, symbol and banner checks.

## 2. Facts verified against QEMU sources

- https://www.qemu.org/docs/master/system/arm/integratorcp.html —
  the integratorcp machine supports ARM1136 and has two PL011 UARTs.
- QEMU hw/arm/integratorcp.c — SDRAM at 0x00000000 (aliased at
  0x80000000); UART0 (first serial port) is a PL011 at 0x16000000;
  default CPU is arm926, so -cpu arm1136 must be passed explicitly.
- QEMU hw/arm/boot.c — an ELF passed via -kernel is loaded at its
  program-header addresses and the CPU starts at the ELF entry point.
- QEMU hw/char/pl011.c — register offsets (DR 0x00, FR 0x18, IBRD
  0x24, FBRD 0x28, LCR_H 0x2C, CR 0x30, IMSC 0x38, ICR 0x44), TXFF is
  bit 5 of FR, and data writes are dropped unless CR.UARTEN is set.

## 3. Acceptance table

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | ELF32 ARM builds successfully | PASS (executed in CI) | ci/evidence/5/01-verify.log |
| 2 | Entry point verified | PASS (executed in CI) | verify_elf.py in the same log: entry 0x00010000 inside PT_LOAD; _start, kmain symbols present |
| 3 | QEMU configuration matches ARM1136 | PASS (executed in CI) | the kernel booted under -M integratorcp -cpu arm1136 (ci/evidence/5/02-qemu.log) |
| 4 | Kernel actually executes, not just loads | PASS (executed in CI) | ci/evidence/5/02-uart.log |
| 5 | UART prints MINITOS KERNEL STARTED | PASS (executed in CI) | ci/evidence/5/02-uart.log |
| 6 | Rebuild reproduces byte-identical output | PASS (executed in CI) | ci/evidence/5/03-rebuild.log — two clean builds, equal SHA-256 |
| 7 | Unverified assumptions and limits documented | DONE | sections 5-6 and docs/DECISIONS.md |

## 4. Executed UART transcript (ci/evidence/5/02-uart.log)

    MINITOS KERNEL STARTED
    K1 platform: qemu-system-arm -M integratorcp -cpu arm1136
    K1 image base: 0x00010000  stack top: 0x00014330
    K1 idle: entering WFI loop

The stack-top value 0x00014330 printed at runtime matches the linker map;
this is the execution proof of ADR-009 (the banner string alone would
only prove image content).

Image hashes recorded by the executed run:

    minitos-k1.elf  sha256 45782ff492a41c9a9362de18e10f2a2768d088b5551761f0bb8838240ed2967d
    minitos-k1.bin  sha256 019cb43561483a2a20118e1f54c916abf17a3823cb0ea2feb1241750d9dabdf8

Tool versions of the run: ci/evidence/5/00-versions.log.
QEMU exited via the 20 s timeout (exit 124) — expected, because the
kernel parks in WFI after printing.

## 5. Engineering history (honest record of the failures)

- Runs #1-#3 (commits daddc1a, c9a21db, 9475b4d): the workflow file was
  rejected before any job started. Cause: an unquoted colon inside a step
  name ("Reproducibility check: rebuild ...") made the YAML invalid, so
  GitHub could not even read the workflow name. Fixed in 48fe4071.
- Run #4 (48fe4071): the build invoked cc instead of clang — GNU make's
  built-in CC=cc beat the '?=' assignment (ADR-016). The default step
  shell (bash -e without pipefail) also let 'make verify | tee' hide the
  failure, so the pipeline reached QEMU with no kernel. Both fixed in
  43337b2c (':=' assignments; explicit pipefail on steps with pipes).
- Run #5 (43337b2c): all steps PASS. Evidence ci/evidence/5.

## 6. Assumptions after the executed run

1. 24 MHz UART reference clock (ADR-004) — still an assumption for real
   hardware; the executed run used the full init sequence with divisors
   13/1 and QEMU transmitted regardless (QEMU is baud-insensitive).
2. CPU state at entry (privileged ARM state, I/F interrupts masked) —
   held in the executed run: the kernel never touches CPSR and nothing
   fired before the banner.
3. RAM 0x00010000-0x04000000 writable — held in the executed run
   (image, .bss clear and stack all live).
4. No exception before the banner — held in the executed run.

These confirmations apply to the QEMU integratorcp model only. The
Galaxy Gio (MSM7227) remains untouched by K1: different SoC, memory map,
boot protocol and UART; see docs/ARCHITECTURE.md for the porting boundary.

## 7. Out of scope for K1

- Galaxy Gio GT-S5660 / MSM7227: no memory map, boot protocol or UART was
  assumed. The integratorcp machine is a reference board, not a Gio model.
- No MMU, no interrupts, no scheduler, no framebuffer, no RX handling.
  These are planned for K2+ (see docs/ARCHITECTURE.md).
