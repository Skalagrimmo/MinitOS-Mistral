#ifndef MINIT_EXCEPTIONS_H
#define MINIT_EXCEPTIONS_H

#include <stdint.h>

/* ARMv6 exception vector offsets (low-vector table base 0x00000000). */
#define MINIT_VECTOR_RESET     0x00u
#define MINIT_VECTOR_UNDEF     0x04u
#define MINIT_VECTOR_SVC       0x08u
#define MINIT_VECTOR_PABT      0x0Cu
#define MINIT_VECTOR_DABT      0x10u
#define MINIT_VECTOR_RESERVED  0x14u
#define MINIT_VECTOR_IRQ       0x18u
#define MINIT_VECTOR_FIQ       0x1Cu

/*
 * Exception frame — the exact layout built by the EXC_ENTRY wrappers in
 * src/exceptions/vectors.S. 18 words, built on the banked stack of the
 * entered exception mode. The wrapper guarantees sp is 8-byte aligned at
 * the C call, so this layout satisfies the AAPCS.
 *
 * dfsr/dfar are read from CP15 c5/c6 and are meaningful only for
 * Data Abort; for all other vectors the wrapper stores 0.
 */
typedef struct minit_exc_frame {
    uint32_t r[13];   /* r0..r12 exactly as on exception entry */
    uint32_t lr;      /* banked LR of the exception mode (ARM state) */
    uint32_t spsr;    /* SPSR of the exception mode */
    uint32_t vector;  /* one of MINIT_VECTOR_* */
    uint32_t dfsr;    /* CP15 c5, Data Abort only */
    uint32_t dfar;    /* CP15 c6, Data Abort only */
} minit_exc_frame_t;

/* Compile-time contract checks (TZ K2-10). */
_Static_assert(sizeof(minit_exc_frame_t) == 18u * 4u, "exception frame must be 18 words");
_Static_assert(_Alignof(minit_exc_frame_t) == 4u, "exception frame alignment must be 4");

/* Fail-stop C dispatcher; never returns (TZ K2-11). */
void minit_exception_dispatch(const minit_exc_frame_t *frame);

#endif /* MINIT_EXCEPTIONS_H */
