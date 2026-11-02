#ifndef MINIT_UART_H
#define MINIT_UART_H

#include <stdint.h>

/*
 * Early console API (K1): polling, TX only.
 * Contract: functions may be called only after uart0_init().
 * They never block indefinitely in QEMU; on real hardware they spin
 * while the TX FIFO is full.
 */

void uart0_init(void);
void uart0_putc(char c);
void uart0_puts(const char *s);
void uart0_puthex32(uint32_t v);

#endif /* MINIT_UART_H */
