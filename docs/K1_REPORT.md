# MinitOS K1 — Acceptance Report

Date: 2026-11-02. Author environment: no ARM toolchain, no QEMU available
at authoring time. Policy: a check is only marked PASS when it actually
ran; everything else is NOT RUN and says exactly how to run it.

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
  equality, entry-in-PT_LOAD, symbol and banner checks (tools/verify_elf.py).

## 2. Facts verified against QEMU sources

- https://www.qemu.org/docs/master/system/arm/integratorcp.html —
  the integratorcp machine supports ARM1136 and has two PL011 UARTs.
- QEMU hw/arm/integratorcp.c — SDRAM at 0x00000000 (aliased at 0x80000000);
  UART0 (first serial port) is a PL011 at 0x16000000; default CPU is arm926,
  so -cpu arm1136 must be passed explicitly.
- QEMU hw/arm/boot.c — an ELF passed via -kernel is loaded at its
  program-header addresses and the CPU starts at the ELF entry point
  ("raw images are linux kernels, and ELF images are not").
- QEMU hw/char/pl011.c — register offsets (DR 0x00, FR 0x18, IBRD 0x24,
  FBRD 0x28, LCR_H 0x2C, CR 0x30, IMSC 0x38, ICR 0x44), TXFF is bit 5 of
  FR, and data writes are dropped unless CR.UARTEN is set.

## 3. Acceptance table

| # | Criterion | Mechanism | Status |
|---|---|---|---|
| 1 | ELF32 ARM builds successfully | make all (clang arm-none-eabi + lld) | NOT RUN — no toolchain in the authoring environment |
| 2 | Entry point verified | tools/verify_elf.py: e_entry == 0x00010000 and inside PT_LOAD | NOT RUN — script ready, run make verify |
| 3 | QEMU config matches ARM1136 | scripts/run-qemu.sh: -M integratorcp -cpu arm1136 | DONE as configuration; verified against QEMU sources; the run itself NOT RUN |
| 4 | Kernel actually executes (not just loads) | UART banner plus runtime-printed link-time constants | NOT RUN — requires QEMU; run make run |
| 5 | UART prints MINITOS KERNEL STARTED | uart0_puts in kmain via PL011 @ 0x16000000 | NOT RUN — driver written against verified PL011/QEMU facts |
| 6 | Rebuild is reproducible | --build-id=none, fixed flags, SHA-256 printed by verify_elf.py | NOT RUN — build twice and compare hashes |
| 7 | Unverified assumptions and limits documented | this file + docs/DECISIONS.md | DONE |

How to produce the missing results on a machine with the toolchain:

    make verify    # criteria 1, 2 and part of 6
    make run       # criteria 4, 5; quit QEMU with Ctrl-A then X
    make clean && make verify && make clean && make verify   # criterion 6

## 4. Expected run transcript (to be confirmed by a real run)

    MINITOS KERNEL STARTED
    K1 platform: qemu-system-arm -M integratorcp -cpu arm1136
    K1 image base: 0x00010000  stack top: 0x0001....
    K1 idle: entering WFI loop

## 5. Unverified assumptions

1. UART reference clock is 24 MHz (baud divisors 13/1). Harmless in QEMU
   (baud is ignored); matters on real hardware. ADR-004.
2. CPU comes out of QEMU reset in a privileged ARM state with I/F
   interrupts masked. Standard ARM reset state; not separately verified
   for the arm1136 model. K1 enables no interrupt sources, so this is
   only a defence-in-depth assumption.
3. RAM is writable from 0x00010000 up to 64 MiB. True on the emulated
   board when -m 64M is passed (the run script pins it); the QEMU default
   RAM size differs, so do not run without the script.
4. No exception occurs before the banner is printed. If one does, the CPU
   jumps to 0x0 (zeroed RAM) and behaviour is undefined (ADR-011).

## 6. Out of scope for K1 (explicit)

- Galaxy Gio GT-S5660 / MSM7227: no memory map, boot protocol or UART was
  assumed. The integratorcp machine is a reference board, not a Gio model.
- No MMU, no interrupts, no scheduler, no framebuffer, no RX handling.
  These are planned for K2+ (see docs/ARCHITECTURE.md).
