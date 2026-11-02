/*
 * MinitOS K2 — fault-test orchestration (TZ sections 5.2, 5.3, 6).
 *
 * The SCTLR read-modify-write for the alignment test happens here, with a
 * read-back verification printed as executed evidence before the fault is
 * triggered. All tests are fail-stop by design.
 */

#include <stdint.h>

#include "minit/tests.h"
#include "minit/uart.h"

/* Defined in the .data segment: real RAM, 4-byte aligned. */
uint8_t minit_test_area[8] __attribute__((aligned(4))) = {1u, 2u, 3u, 4u, 5u, 6u, 7u, 8u};

static inline uint32_t sctlr_read(void)
{
    uint32_t value;
    __asm__ volatile ("mrc p15, 0, %0, c1, c0, 0" : "=r"(value));
    return value;
}

static inline void sctlr_write(uint32_t value)
{
    __asm__ volatile ("mcr p15, 0, %0, c1, c0, 0" :: "r"(value));
}

static void fail_halt(const char *message)
{
    uart0_puts(message);
    for (;;) {
        __asm__ volatile ("mcr p15, 0, r0, c7, c0, 4" ::: "memory");
    }
}

void minit_test_run_undef(void)
{
    uart0_puts("K2 test: executing UDF (.inst 0xE7F000F0)\r\n");
    minit_test_trigger_undef();
    fail_halt("K2 FATAL: undefined-instruction test unexpectedly returned\r\n");
}

void minit_test_run_data_abort(void)
{
    uart0_puts("K2 test: strict alignment via SCTLR.U=1, SCTLR.A=1\r\n");

    /* Read-modify-write of SCTLR preserving all other bits (TZ 5.3). */
    uint32_t sctlr = sctlr_read();
    sctlr |= (1u << 22) | (1u << 1);
    sctlr_write(sctlr);

    /* Read-back verification — executed evidence for the test setup. */
    uint32_t readback = sctlr_read();
    uart0_puts("K2 sctlr (after RMW): ");
    uart0_puthex32(readback);
    uart0_puts("\r\n");
    if ((readback & (1u << 22)) == 0u || (readback & (1u << 1)) == 0u) {
        fail_halt("K2 FATAL: SCTLR U/A bits not set in read-back\r\n");
    }

    uart0_puts("K2 test: unaligned word LDR from ");
    uart0_puthex32((uint32_t)(uintptr_t)&minit_test_area + 1u);
    uart0_puts("\r\n");
    minit_test_trigger_data_abort();
    fail_halt("K2 FATAL: data-abort test unexpectedly returned\r\n");
}
