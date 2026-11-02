/*
 * PL011 UART driver — polling, TX only (K1).
 *
 * Register offsets verified against QEMU hw/char/pl011.c (word index:
 * DR=0, FR=6, IBRD=9, FBRD=10, LCR_H=11, CR=12, IMSC=14, ICR=17).
 * The UART0 base address comes from include/minit/platform.h.
 *
 * Important QEMU behaviour (verified in pl011_write_txdata): a write to
 * the data register is silently dropped unless CR.UARTEN is set, so a
 * full init sequence is mandatory, not optional (ADR-005).
 */

#include <stdint.h>

#include "minit/platform.h"
#include "minit/uart.h"

#define UART0_BASE       MINIT_UART0_BASE

#define UART_DR          0x00u   /* data register            */
#define UART_FR          0x18u   /* flag register            */
#define UART_IBRD        0x24u   /* integer baud divisor     */
#define UART_FBRD        0x28u   /* fractional baud divisor  */
#define UART_LCRH        0x2Cu   /* line control             */
#define UART_CR          0x30u   /* control register         */
#define UART_IMSC        0x38u   /* interrupt mask set/clear */
#define UART_ICR         0x44u   /* interrupt clear          */

#define FR_TXFF          (1u << 5)

#define CR_UARTEN        (1u << 0)
#define CR_TXE           (1u << 8)
#define CR_RXE           (1u << 9)

#define LCRH_FEN         (1u << 4)
#define LCRH_WLEN_8BIT   (3u << 5)

/*
 * Baud divisors assume a 24 MHz UART reference clock (the integratorcp
 * core module reference counter runs at 24 MHz in QEMU). For 115200 8N1:
 *   divisor = 24e6 / (16 * 115200) = 13.02  ->  IBRD = 13, FBRD = 1
 * QEMU's PL011 model transmits regardless of the programmed baud rate,
 * so this assumption changes nothing on the virtual board; it is
 * recorded because it will matter on real hardware (ADR-004).
 */
#define BAUD_IBRD        13u
#define BAUD_FBRD        1u

static volatile uint32_t *reg(uint32_t offset)
{
    return (volatile uint32_t *)(uintptr_t)(UART0_BASE + offset);
}

void uart0_init(void)
{
    /* Order per the PL011 TRM: disable, configure, (re)enable. */
    *reg(UART_CR)   = 0u;                     /* disable UART             */
    *reg(UART_ICR)  = 0x7FFu;                 /* clear pending interrupts  */
    *reg(UART_IBRD) = BAUD_IBRD;
    *reg(UART_FBRD) = BAUD_FBRD;
    *reg(UART_LCRH) = LCRH_WLEN_8BIT | LCRH_FEN;
    *reg(UART_IMSC) = 0u;                     /* no interrupt sources      */
    *reg(UART_CR)   = CR_UARTEN | CR_TXE | CR_RXE;
}

void uart0_putc(char c)
{
    while ((*reg(UART_FR) & FR_TXFF) != 0u) {
        /* spin until the TX FIFO has room */
    }
    *reg(UART_DR) = (uint32_t)(uint8_t)c;
}

void uart0_puts(const char *s)
{
    while (*s != '\0') {
        uart0_putc(*s++);
    }
}

void uart0_puthex32(uint32_t v)
{
    static const char digits[] = "0123456789abcdef";

    uart0_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart0_putc(digits[(v >> (uint32_t)i) & 0xFu]);
    }
}
