#ifndef MINIT_PLATFORM_H
#define MINIT_PLATFORM_H

/*
 * K1 platform: QEMU integratorcp (ARM1136 reference machine).
 *
 * All hardware-dependent constants live in this single header so that a
 * future port (e.g. Galaxy Gio / MSM7227) replaces exactly one file and
 * the rest of the kernel stays untouched (ADR-012).
 *
 * UART0 base verified against QEMU hw/arm/integratorcp.c:
 * pl011_create(0x16000000, ...) is the first serial port.
 */

#define MINIT_UART0_BASE 0x16000000u

#endif /* MINIT_PLATFORM_H */
