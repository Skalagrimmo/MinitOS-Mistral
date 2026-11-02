#!/bin/sh
# MinitOS K2 — boot one scenario image in QEMU (interactive).
#
# Pinned environment (TZ MINITOS-K2-TZ, section 3.1):
#   -M integratorcp -cpu arm1136 -m 128M
# QEMU loads the ELF at its program-header addresses and starts at
# the ELF entry point; UART0 (PL011 at 0x16000000) goes to stdio.
# Quit inside QEMU: Ctrl-A then X.

set -eu

SCENARIO="${SCENARIO:-normal}"
KERNEL="${KERNEL:-build/minitos-k2-$SCENARIO.elf}"

exec qemu-system-arm \
    -M integratorcp \
    -cpu arm1136 \
    -m 128M \
    -nographic \
    -kernel "$KERNEL"
