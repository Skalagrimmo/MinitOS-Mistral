#!/bin/sh
# MinitOS K1 — boot the kernel in QEMU on the integratorcp reference machine.
#
# Pinned environment (ADR-002/ADR-003/ADR-007):
#   -M integratorcp -cpu arm1136   ARM1136 is documented as supported by the
#                                  integratorcp machine.
#   -m 64M                         RAM size must match linker/integratorcp.ld.
#   -kernel <ELF>                  QEMU loads PT_LOAD segments at their virtual
#                                  addresses and starts at the ELF entry point
#                                  (verified in QEMU hw/arm/boot.c).
#   -nographic                     UART0 (PL011 @ 0x16000000) is the first serial
#                                  port and is connected to stdio.
#
# Quit QEMU: Ctrl-A then X.

set -eu

QEMU="${QEMU:-qemu-system-arm}"
KERNEL="${KERNEL:-build/minitos-k1.elf}"

exec "$QEMU" \
    -M integratorcp \
    -cpu arm1136 \
    -m 64M \
    -nographic \
    -kernel "$KERNEL"
