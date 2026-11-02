/*
 * MinitOS K2 — raw fault triggers (TZ sections 5.2, 5.3).
 *
 * Both triggers are hand-written ARM instructions so the compiler cannot
 * optimize the fault away or replace the word load with byte loads. The
 * generated encodings are checked statically by tools/verify_elf.py and
 * shown in build/disassembly-handlers.txt.
 */

.syntax unified
.cpu arm1136jf-s
.arm

.section .text.tests, "ax", %progbits

/*
 * Undefined Instruction trigger: .inst 0xE7F000F0 — the permanently
 * undefined ARM encoding (UDF pattern, UNPREDICTABLE-free defined trap).
 * Bytes in the ELF: F0 00 F0 E7 (little-endian).
 */
.global minit_test_trigger_undef
.type minit_test_trigger_undef, %function
minit_test_trigger_undef:
    .inst 0xE7F000F0
    b   minit_test_trigger_undef

/*
 * Data Abort trigger: a single word LDR from an address misaligned by one
 * byte inside minit_test_area (RAM). With SCTLR.U=1 and SCTLR.A=1 this
 * raises a precise Alignment Fault Data Abort through vector 0x10.
 */
.global minit_test_trigger_data_abort
.type minit_test_trigger_data_abort, %function
minit_test_trigger_data_abort:
    ldr     r0, =minit_test_area
    add     r0, r0, #1
    ldr     r1, [r0]
    b   minit_test_trigger_data_abort
