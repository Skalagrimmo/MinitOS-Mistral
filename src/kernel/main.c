/*
 * MinitOS K1 — kernel entry after early boot (src/boot/start.S).
 *
 * The K1 acceptance requires the UART line "MINITOS KERNEL STARTED" as
 * proof that the kernel really executes. To make that proof stronger
 * than a static string baked into the image, the banner is followed by
 * link-time constants printed as hex at runtime (ADR-009).
 */

#include <stdint.h>

#include "minit/kernel.h"
#include "minit/uart.h"

/* Provided by linker/integratorcp.ld. */
extern char __image_start__;
extern char __stack_top__;

static void print_report(void)
{
    uart0_puts("K1 image base: ");
    uart0_puthex32((uint32_t)(uintptr_t)&__image_start__);
    uart0_puts("  stack top: ");
    uart0_puthex32((uint32_t)(uintptr_t)&__stack_top__);
    uart0_puts("\r\n");
}

void kmain(void)
{
    uart0_init();

    uart0_puts("\r\n");
    uart0_puts("MINITOS KERNEL STARTED\r\n");
    uart0_puts("K1 platform: qemu-system-arm -M integratorcp -cpu arm1136\r\n");
    print_report();
    uart0_puts("K1 idle: entering WFI loop\r\n");

    for (;;) {
        /*
         * ARMv6 wait-for-interrupt (cp15 form). arm1136jf-s is ARMv6, so
         * the ARMv7 'wfi' mnemonic is not available. No interrupt sources
         * are enabled in K1, so the CPU parks here (ADR-008).
         */
        __asm__ volatile ("mcr p15, 0, r0, c7, c0, 4" ::: "memory");
    }
}
