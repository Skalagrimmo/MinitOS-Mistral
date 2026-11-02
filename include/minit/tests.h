#ifndef MINIT_TESTS_H
#define MINIT_TESTS_H

#include <stdint.h>

/* Build-profile scenario ids (TZ section 6), set via -DMINIT_TEST_SCENARIO. */
#define MINIT_SCENARIO_NORMAL     0
#define MINIT_SCENARIO_UNDEF      1
#define MINIT_SCENARIO_DATA_ABORT 2

/* Test data area in .data (RAM), 4-byte aligned; the alignment test loads
   a word from &minit_test_area[1] which is misaligned by one byte. */
extern uint8_t minit_test_area[8];

/* Orchestration (SCTLR RMW, prints) in scenarios.c. */
void minit_test_run_undef(void);
void minit_test_run_data_abort(void);

/* Raw fault triggers in faults.S — real faulting instructions, never
   plain C calls (TZ 5.2/5.3). Neither trigger ever returns in K2. */
void minit_test_trigger_undef(void);
void minit_test_trigger_data_abort(void);

#endif /* MINIT_TESTS_H */
