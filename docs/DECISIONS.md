## ADR-015: CI is the executed acceptance harness

GitHub Actions (.github/workflows/k1.yml) installs clang/lld/llvm/binutils
and qemu-system-arm on every push to main, then: records tool versions,
builds and statically verifies the image, boots the kernel headless in
QEMU with the UART captured to a log, greps the required banner, rebuilds
from scratch and requires a byte-identical SHA-256. Every run publishes
its step logs to an evidence branch ci/evidence/<run_number>, so results
are verifiable without access to the Actions UI. Only checks that actually
executed are marked PASS anywhere in this project.

## ADR-016: Tool variables use ':=', not '?='

GNU make ships CC as a built-in variable defaulting to 'cc'. CC ?= clang
therefore never assigns, and CI run #4 silently built with the host
compiler ('--target=arm-none-eabi unrecognized'). All tool variables in
the Makefile are pinned with ':='; a command-line override
(make CC=clang-19 ...) still wins, since command-line assignments beat
file assignments in GNU make.

## ADR-017: Low vectors via SCTLR.V = 0 with read-back

ARM1136 selects the vector base with SCTLR.V (bit 13): 0 -> 0x00000000,
1 -> 0xFFFF0000. K2 clears V with a read-modify-write and verifies it by
read-back, storing the result in .data before .bss clearing. High vectors
were not adopted because 0xFFFF0000 is not a proven RAM region on the
QEMU machine; RAM at 0x00000000 is proven.

## ADR-018: Vectors as a separate PT_LOAD at 0x00000000

The vector table is a 32-byte .vectors output section in its own R+E,
non-writable PT_LOAD segment with p_vaddr = p_paddr = 0x00000000. The
kernel image stays at 0x00010000 (K1 placement), so the stage does not
relocate already-verified code. The difference between the ELF entry
point and the reset vector is documented in EXCEPTION_ABI.md.

## ADR-019: Banked stacks in the linker script

Five banked stacks (IRQ, FIQ, UND, ABT: 0x400 each; SVC: 0x2000) are
laid out statically in a .stacks NOLOAD section with exported boundary
symbols, 16-byte region alignment, 8-byte aligned tops, and an exact
size ASSERT. Boundaries are printed at runtime and the tops' alignment
is checked by tools/verify_elf.py. Startup installs them by switching to
each mode with IRQ/FIQ still masked.

## ADR-020: 18-word exception frame with compile-time contract

minit_exc_frame_t fixes the frame: r0-r12, banked LR, SPSR, vector
offset, DFSR, DFAR (72 bytes). _Static_assert pins size and alignment;
the assembly wrapper builds exactly this layout and guarantees an
8-byte aligned sp at the C call (stack tops are 16-byte aligned).

## ADR-021: Handlers run in the entered exception mode

The C dispatcher runs on the banked stack of the entered mode instead of
switching to a panic stack. Rationale: banked LR/SPSR are saved in the
frame before any mode-dependent state could be lost, SPSR stays valid,
and no second stack discipline is needed. The dispatcher never returns
(fail-stop, TZ 5.4); recovery is a later stage.

## ADR-022: UDF trigger as .inst 0xE7F000F0 in assembly

The undefined-instruction test executes the permanently-undefined ARM
encoding 0xE7F000F0 from assembly (never a plain C call, never an
uncontrolled CP15 access). The encoding is verified statically by
tools/verify_elf.py and visible in disassembly-handlers.txt; the runtime
fault_pc (0x00010634) matched the disassembly exactly in run 5.

## ADR-023: Alignment fault via SCTLR.U/A with dual DFSR decoding

The data-abort test works on real RAM (minit_test_area in .data), sets
SCTLR.U (bit 22) and SCTLR.A (bit 1) with read-modify-write and
read-back, then executes one assembly word LDR from a +1 misaligned
address. The handler asserts the Alignment Fault status (0b00001) and
that DFAR equals the test address. QEMU 8.2.2 was observed to encode the
status in DFSR bits [4:0] (raw 0x00000001) instead of the ARM1136 TRM
layout (bits [3:1] + bit 10); the handler accepts either layout, prints
the raw DFSR, and the deviation is recorded in
ASSUMPTIONS_AND_LIMITATIONS.md rather than hidden.

## ADR-024: Scenario build profiles instead of runtime selection

Each TZ scenario is a separate ELF (minitos-k2-{normal,undef,data-abort})
differing only in -DMINIT_TEST_SCENARIO on kmain. This keeps a single
deterministic image per run (no boot-parameter channel exists on the
QEMU ELF path) and gives each scenario its own reproducible hash.

## ADR-025: Marker-terminated QEMU harness

scripts/k2-harness.sh runs each scenario in its own QEMU process, polls
the UART log for the scenario's terminal marker (idle marker for normal,
"K2 EXCEPTION CAPTURED" for fault scenarios) and kills QEMU explicitly.
Exit is 0 only on the marker; a hang without output is a failure, so no
green result can come from an unobserved run.

## ADR-026: Static verifier extended for K2

verify_elf.py now checks EABI5 e_flags, the vector segment (vaddr 0,
filesz 32, R+E, non-writable, eight branch words with in-RAM targets),
required symbols including five stack tops with 8-byte alignment, the
absence of undefined symbols (no accidental libc/libgcc helpers), the
banner and exception strings, the UDF byte pattern, and prints SHA-256
of ELF and BIN for reproducibility.

## ADR-027: Section-start alignment via address expression

The first K2 link failed the exact-size ASSERT on .stacks: an internal
". = ALIGN(16)" counts its padding into SIZEOF(.stacks). The fix aligns
the section start in the section address expression (.stacks ALIGN(16)
(NOLOAD) without internal alignment), so SIZEOF is exactly 0x3000.
Lesson recorded from executed CI run 1, not from theory.

## ADR-028: K2 evidence in its own branch namespace

K2 CI run numbers restarted and collided with retired K1 evidence
branches (a non-fast-forward push failed in run 4). K2 evidence now
publishes to ci/evidence/k2/<run_number>; K1 evidence branches remain
untouched as historical artifacts.
