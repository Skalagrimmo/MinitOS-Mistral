# MinitOS K2 — Acceptance Report

Stage: K2 (ARMv6 exception handling), TZ MINITOS-K2-TZ v0.1.
This table references only evidence that actually executed.

Executed environment (docs/evidence/00-versions.log,
docs/evidence/qemu-platform.log): clang/LLVM 18.1.3, GNU binutils 2.42,
Python 3.12.3, QEMU 8.2.2, machine integratorcp, CPU arm1136, RAM 128M.
Full CI evidence of the accepted run: branch \`ci/evidence/k2/5\`
(commit 05e614f3); copies of all logs are committed in docs/evidence/.

| ID | Criterion | Status | Evidence |
|---|---|---|---|
| K2-01 | K1 preserved with a baseline build/run | PASS | K1 final commit 80cc243c; K1 CI logs in branch ci/evidence/5 (build, verify, QEMU boot, repro hashes) and docs/K1_REPORT.md. K1 sources remain in git history; K2 replaced only what the stage requires. |
| K2-02 | Vector table has all 8 slots | PASS | elf-check.log: PT_LOAD at vaddr 0, 32 bytes, R+E; disassembly-vectors.txt: 8 branch slots; linker-map.txt: _vector_table size 0x20 |
| K2-03 | Vector base matches ARM1136 and is really active | PASS | Startup clears SCTLR.V with read-modify-write + read-back (start.S); runtime prints "K2 sctlr: 0x00050078" (bit13=0) in all three UART logs; the real proof is that undef/data-abort actually entered through vectors 0x04/0x10 |
| K2-04 | Vectors at 0x10000 not mistaken for the active table | PASS | Active base is 0x00000000 (own PT_LOAD segment); the image at 0x10000 is code, documented in EXCEPTION_ABI.md and ASSUMPTIONS_AND_LIMITATIONS.md |
| K2-05 | SVC/UND/ABT stacks defined before C/handlers | PASS | start.S mode switches; linker-map.txt stack symbols; runtime "K2 stack:" lines; verifier checks 8-byte alignment of all five stack tops |
| K2-06 | IRQ/FIQ masked with controlled stubs | PASS | Runtime "K2 cpsr: 0x600001d3" (SVC, I=1, F=1) in all logs; stubs minit_entry_irq/fiq exist and lead to the dispatcher (disassembly-handlers.txt); no interrupt controller is touched in K2 |
| K2-07 | Undefined Instruction really enters UND mode | PASS | undef-uart.log: "EXCEPTION: UNDEFINED INSTRUCTION", "vector: 0x00000004", "mode: UND", spsr 0x600001d3 (came from SVC), fault_pc 0x00010634 == UDF address in disassembly-handlers.txt |
| K2-08 | Data Abort really enters ABT mode | PASS | data-abort-uart.log: "EXCEPTION: DATA ABORT", "vector: 0x00000010", "mode: ABT", spsr 0x600001d3 |
| K2-09 | Alignment test is a real unaligned LDR from RAM | PASS | disassembly-handlers.txt: single "ldr r1, [r0]" at 0x10644 after "add r0, r0, #1" on minit_test_area (.data, RAM); fault_pc 0x00010644 matches; SCTLR RMW read-back 0x0045007a (U=1, A=1); "K2 ALIGNMENT FAULT CONFIRMED" is an executed assertion on DFSR; "K2 DFAR MATCH TEST AREA" executed, DFAR 0x00010da5 == the printed test address |
| K2-10 | Exception frame has a fixed format | PASS | include/minit/exceptions.h: minit_exc_frame_t with _Static_assert size 72 bytes and alignment 4; the wrapper stores exactly this layout (disassembly-handlers.txt offsets 0x34..0x44) |
| K2-11 | Controlled stop after a fault | PASS | "K2 EXCEPTION CAPTURED" then WFI halt loop in all fault logs; harness terminates QEMU at the marker; no reset loop |
| K2-12 | normal / undef / data-abort run separately | PASS | Three separate QEMU processes via scripts/k2-harness.sh; three logs: normal-uart.log, undef-uart.log, data-abort-uart.log |
| K2-13 | Rebuild reproducible | PASS | repro-hashes.txt: byte-identical SHA-256 for all three ELFs across two clean builds in the same run |
| K2-14 | Assumptions and limits documented | PASS | docs/ASSUMPTIONS_AND_LIMITATIONS.md, docs/DECISIONS.md (ADR-017..028), EXCEPTION_ABI.md |

## Honest failure history of this stage

- CI run 1 (commit b226053d): link failed, \`ASSERT(SIZEOF(.stacks) ==
  0x3000)\` — an internal ALIGN(16) counted padding into the section
  size. Fixed by aligning the section start via its address expression
  (commit bc2cf960).
- CI run 3 (commit 71e849dc... predecessor 88afa2af/71e849dc): all three
  scenarios executed, but the alignment-fault status was not confirmed:
  QEMU 8.2.2 reports DFSR = 0x00000001 (status in bits [4:0]) while the
  first implementation only accepted the ARM1136 TRM layout (bits [3:1]
  plus bit 10). The dispatcher now accepts either encoding and logs the
  raw DFSR; the deviation is documented (commit 71e849dc, ADR-023).
- CI run 4: passed all checks but could not publish evidence — the
  evidence branch name collided with a retired K1 branch. Fixed by
  moving K2 evidence to ci/evidence/k2/<n> (commit 05e614f3).
- CI run 5 (commit 05e614f3): fully green; this is the accepted run.

## Boundaries

All evidence is QEMU Integrator/CP only. Nothing here is a claim about
Galaxy Gio GT-S5660 / MSM7227: vector base, RAM map and boot protocol of
that board are unverified (see ASSUMPTIONS_AND_LIMITATIONS.md).
