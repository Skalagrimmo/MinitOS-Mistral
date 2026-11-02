# MinitOS — K1 (independent implementation)

MinitOS is an independent bare-metal OS project targeting ARMv6 hardware.
K1 is the first stage that actually executes: the kernel boots on the QEMU
integratorcp reference machine (ARM1136), initializes the PL011 UART
and prints a visible execution proof over serial:

    MINITOS KERNEL STARTED

- Target ISA: ARMv6, ARM state, 32-bit little-endian, soft-float ABI.
- Toolchain: Clang/LLVM targeting arm-none-eabi (K0 reference build: Clang 17.0.0).
- Reference machine: qemu-system-arm -M integratorcp -cpu arm1136.
- Future direction: Samsung Galaxy Gio GT-S5660 (Qualcomm MSM7227-1, ARMv6).
  Nothing in K1 is a claim about that board — see docs/K1_REPORT.md.

## Build

Requires: clang with ARM backend, lld, llvm-objcopy, llvm-objdump,
GNU readelf, python3, make, and qemu-system-arm to run.

    make clean
    make verify    # build + static ELF checks
    make run       # boot in QEMU; quit with Ctrl-A then X

## Expected UART output

    MINITOS KERNEL STARTED
    K1 platform: qemu-system-arm -M integratorcp -cpu arm1136
    K1 image base: 0x00010000  stack top: <hex printed at runtime>
    K1 idle: entering WFI loop

The hex values are link-time constants printed by executing code; seeing
them on the serial line is the runtime proof (see docs/DECISIONS.md, ADR-009).

## Layout

    include/minit/   kernel API headers
    src/boot/        entry assembly (stack, BSS clear)
    src/drivers/     PL011 UART driver
    src/kernel/      kernel main
    linker/          linker script for integratorcp
    tools/           verify_elf.py — static artifact checks
    scripts/         run-qemu.sh — QEMU launch
    docs/            architecture, decision log, acceptance report

## Status and honesty policy

Sources and static checks are complete. This repository was authored in an
environment without an ARM toolchain and without QEMU, so compile and
runtime results must be produced by running make on a development
machine. docs/K1_REPORT.md keeps a strict table of what was actually
executed versus what was not; no check is claimed PASS without a run.
