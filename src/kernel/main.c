/*
 * MinitOS K2 — kernel entry (extends the K1 proof with exception
 * handling per TZ MINITOS-K2-TZ).
 */

#include <stdint.h>

#include "minit/kernel.h"
#include "minit/tests.h"
#include "minit/uart.h"

/*
 * Written by src/boot/start.S right after the SCTLR.V read-back. Lives in
 * .data (not .bss) so the startup store survives .bss clearing. The
 * sentinel value proves the store actually happened before kmain.
 */
uint32_t minit_sctlr_after_setup = 0xAAAAAAAAu;

#define MINIT_SCTLR_SENTINEL 0xAAAAAAAAu
#define MINIT_SCTLR_V        (1u << 13)

/* Banked stack boundaries from linker/integratorcp.ld. */
extern char __svc_stack_bottom__[];
extern char __svc_stack_top__[];
extern char __und_stack_bottom__[];
extern char __und_stack_top__[];
extern char __abt_stack_bottom__[];
extern char __abt_stack_top__[];
extern char __irq_stack_bottom__[];
extern char __irq_stack_top__[];
extern char __fiq_stack_bottom__[];
extern char __fiq_stack_top__[];

static inline uint32_t cpsr_read(void)
{
    uint32_t value;
    __asm__ volatile ("mrs %0, cpsr" : "=r"(value));
    return value;
}

static void halt_forever(void)
{
    for (;;) {
        __asm__ volatile ("mcr p15, 0, r0, c7, c0, 4" ::: "memory");
    }
}

static void print_stack(const char *name, uintptr_t bottom, uintptr_t top)
{
    uart0_puts("K2 stack: ");
    uart0_puts(name);
    uart0_puts(" ");
    uart0_puthex32((uint32_t)bottom);
    uart0_puts("-");
    uart0_puthex32((uint32_t)top);
    uart0_puts("\r\n");
}

void kmain(void)
{
    uart0_init();

    uart0_puts("\r\nMINITOS KERNEL STARTED\r\n");
    uart0_puts("K2 platform: qemu-system-arm -M integratorcp -cpu arm1136 -m 128M\r\n");

    /* K2-03: vector base selection evidence — SCTLR.V read-back. */
    if (minit_sctlr_after_setup == MINIT_SCTLR_SENTINEL) {
        uart0_puts("K2 FATAL: SCTLR read-back was not performed by startup\r\n");
        halt_forever();
    }
    uart0_puts("K2 sctlr: ");
    uart0_puthex32(minit_sctlr_after_setup);
    uart0_puts("\r\n");
    if ((minit_sctlr_after_setup & MINIT_SCTLR_V) != 0u) {
        uart0_puts("K2 FATAL: SCTLR.V is set, low vectors not active\r\n");
        halt_forever();
    }
    uart0_puts("K2 vectors: low @ 0x00000000\r\n");

    /* K2-06: CPSR evidence — SVC mode with IRQ/FIQ masked. */
    uart0_puts("K2 cpsr: ");
    uart0_puthex32(cpsr_read());
    uart0_puts("\r\n");

    /* K2-05: banked stack boundaries as linked (also in linker map). */
    print_stack("svc", (uintptr_t)__svc_stack_bottom__, (uintptr_t)__svc_stack_top__);
    print_stack("und", (uintptr_t)__und_stack_bottom__, (uintptr_t)__und_stack_top__);
    print_stack("abt", (uintptr_t)__abt_stack_bottom__, (uintptr_t)__abt_stack_top__);
    print_stack("irq", (uintptr_t)__irq_stack_bottom__, (uintptr_t)__irq_stack_top__);
    print_stack("fiq", (uintptr_t)__fiq_stack_bottom__, (uintptr_t)__fiq_stack_top__);

#if MINIT_TEST_SCENARIO == MINIT_SCENARIO_UNDEF
    uart0_puts("K2 test: undefined\r\n");
    minit_test_run_undef();
#elif MINIT_TEST_SCENARIO == MINIT_SCENARIO_DATA_ABORT
    uart0_puts("K2 test: data-abort\r\n");
    minit_test_run_data_abort();
#else
    uart0_puts("K2 test: normal\r\n");
    uart0_puts("K2 idle: entering WFI loop\r\n");
    halt_forever();
#endif

    halt_forever(); /* not reached: every branch above halts */
}
