# MinitOS — K2 (independent implementation)

MinitOS is an independent bare-metal OS project targeting ARMv6.
K2 adds ARMv6 exception handling to the bootable K1 kernel and proves
it by execution on the QEMU integratorcp reference machine (ARM1136):

- a real 8-slot vector table at 0x00000000 (low vectors, SCTLR.V = 0
  selected by read-modify-write and verified by read-back);
- banked stacks for SVC/UND/ABT/IRQ/FIQ installed before any C code;
- a fixed 18-word exception frame (r0-r12, banked LR, SPSR, vector,
  DFSR/DFAR) built by assembly wrappers, checked at compile time;
- executed fault tests: a UDF undefined instruction and a strict
  alignment data abort (SCTLR.U=1, SCTLR.A=1, unaligned word LDR),
  each entering through its CPU vector, diagnosed over UART and
  followed by a controlled fail-stop halt.

## Build and run locally

Requires: clang with ARM backend, lld, llvm-objcopy, llvm-objdump,
GNU readelf, python3, make, and qemu-system-arm to run.

    make clean
    make verify    # build all three scenario ELFs + static checks
    make disasm    # vector table / handler disassembly artifacts
    make run                     # scenario "normal" in QEMU (interactive)
    make run SCENARIO=undef      # or SCENARIO=data-abort

## Scenarios (separate ELFs, separate QEMU processes)

| Profile | Terminal UART marker |
|---|---|
| normal | K2 idle: entering WFI loop |
| undef | K2 EXCEPTION CAPTURED (after UND vector diagnostics) |
| data-abort | K2 EXCEPTION CAPTURED (after ABT vector diagnostics) |

Expected key output of the fault scenarios (from the executed CI run):

    MINITOS KERNEL STARTED
    K2 vectors: low @ 0x00000000
    K2 test: undefined
    EXCEPTION: UNDEFINED INSTRUCTION
    vector: 0x00000004
    mode: UND
    ...
    K2 EXCEPTION CAPTURED

## Documentation

- docs/ARCHITECTURE.md — boot and exception flow, layout, modules
- docs/EXCEPTION_ABI.md — startup contract, vectors, frame, LR offsets
- docs/K2_ACCEPTANCE.md — acceptance table K2-01..K2-14 with evidence
- docs/ASSUMPTIONS_AND_LIMITATIONS.md — unverified assumptions, QEMU
  deviations (e.g. the observed DFSR encoding), scope limits
- docs/DECISIONS.md — ADR-015..ADR-028 (K2: ADR-017..028)
- docs/K1_REPORT.md — historical K1 acceptance (baseline commit 80cc243c)
- docs/evidence/ — executed logs of the accepted CI run (branch ci/evidence/k2/5)

## Status

CI (workflow "k2") executes the full acceptance on every push to main:
build of all three scenario ELFs, static verification, three separate
QEMU runs with per-scenario required-line checks (including the
executed DFSR/DFAR assertions), a reproducibility double-build
(byte-identical SHA-256) and publication of the step logs to
ci/evidence/k2/<run_number>. The accepted run is #5 on commit 05e614f3.

## Boundary

QEMU Integrator/CP only. Nothing in this repository is a claim about
Samsung Galaxy Gio GT-S5660 (Qualcomm MSM7227): its memory map, vector
base and boot chain are unverified and out of scope for K2.
