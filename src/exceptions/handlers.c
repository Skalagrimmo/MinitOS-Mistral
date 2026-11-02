/*
 * MinitOS K2 — fail-stop exception dispatcher.
 *
 * Runs in the banked exception mode of the entered vector, on that mode's
 * stack (set by src/boot/start.S). It prints the diagnostic contract of
 * TZ section 5, runs executed runtime assertions for the Data Abort test
 * (DFSR alignment status, DFAR match) and then halts deterministically.
 * K2 performs no recovery: full resumption is out of scope (TZ 5.4, 9).
 */

#include <stdint.h>

#include "minit/exceptions.h"
#include "minit/tests.h"
#include "minit/uart.h"

static void print_label_hex(const char *label, uint32_t value)
{
    uart0_puts(label);
    uart0_puthex32(value);
    uart0_puts("\r\n");
}

static void print_label_str(const char *label, const char *text)
{
    uart0_puts(label);
    uart0_puts(text);
    uart0_puts("\r\n");
}

static const char *vector_name(uint32_t vector)
{
    switch (vector) {
    case MINIT_VECTOR_RESET:    return "RESET";
    case MINIT_VECTOR_UNDEF:    return "UNDEFINED INSTRUCTION";
    case MINIT_VECTOR_SVC:      return "SVC (UNEXPECTED IN K2)";
    case MINIT_VECTOR_PABT:     return "PREFETCH ABORT";
    case MINIT_VECTOR_DABT:     return "DATA ABORT";
    case MINIT_VECTOR_RESERVED: return "RESERVED";
    case MINIT_VECTOR_IRQ:      return "IRQ (UNEXPECTED IN K2)";
    case MINIT_VECTOR_FIQ:      return "FIQ (UNEXPECTED IN K2)";
    default:                    return "UNKNOWN VECTOR";
    }
}

static const char *mode_name(uint32_t vector)
{
    switch (vector) {
    case MINIT_VECTOR_UNDEF:    return "UND";
    case MINIT_VECTOR_SVC:      return "SVC";
    case MINIT_VECTOR_PABT:
    case MINIT_VECTOR_DABT:     return "ABT";
    case MINIT_VECTOR_IRQ:      return "IRQ";
    case MINIT_VECTOR_FIQ:      return "FIQ";
    default:                    return "UNPREDICTABLE";
    }
}

/*
 * ARM-state return-address offsets (ARM1136 TRM, exception entry summary):
 *   UND/SVC/PABT/IRQ/FIQ: banked LR = faulting PC + 4
 *   DABT (precise):       banked LR = faulting PC + 8
 * The reserved slot has no defined semantics.
 */
static uint32_t fault_pc(uint32_t vector, uint32_t lr)
{
    if (vector == MINIT_VECTOR_DABT) {
        return lr - 8u;
    }
    if (vector == MINIT_VECTOR_RESERVED) {
        return 0u;
    }
    return lr - 4u;
}

/*
 * ARMv6 DFSR fault status: FS[3:1] in bits [3:1], FS[0] in bit 10.
 * Alignment fault is FS = 0b00001 (ARM1136 TRM c5).
 */
static uint32_t dfsr_status(uint32_t dfsr)
{
    return (((dfsr >> 1) & 0x7u) << 1) | ((dfsr >> 10) & 1u);
}

static void halt_forever(void)
{
    /* Deterministic fail-stop: WFI loop, no reset, no continued execution. */
    for (;;) {
        __asm__ volatile ("mcr p15, 0, r0, c7, c0, 4" ::: "memory");
    }
}

void minit_exception_dispatch(const minit_exc_frame_t *frame)
{
    uart0_puts("\r\nEXCEPTION: ");
    uart0_puts(vector_name(frame->vector));
    uart0_puts("\r\n");

    print_label_hex("vector: ", frame->vector);
    print_label_str("mode: ", mode_name(frame->vector));
    print_label_hex("lr: ", frame->lr);
    print_label_hex("spsr: ", frame->spsr);

    if (frame->vector == MINIT_VECTOR_DABT) {
        print_label_hex("dfsr: ", frame->dfsr);
        print_label_hex("dfar: ", frame->dfar);
    }

    print_label_hex("fault_pc: ", fault_pc(frame->vector, frame->lr));

    if (frame->vector == MINIT_VECTOR_DABT) {
        uint32_t status = dfsr_status(frame->dfsr);
        if (status == 0x01u) {
            uart0_puts("K2 ALIGNMENT FAULT CONFIRMED\r\n");
        } else {
            print_label_hex("K2 DFSR STATUS UNEXPECTED: ", status);
        }
        if (frame->dfar == ((uint32_t)(uintptr_t)&minit_test_area) + 1u) {
            uart0_puts("K2 DFAR MATCH TEST AREA\r\n");
        } else {
            uart0_puts("K2 DFAR MISMATCH\r\n");
        }
    }

    uart0_puts("K2 EXCEPTION CAPTURED\r\n");
    halt_forever();
}
