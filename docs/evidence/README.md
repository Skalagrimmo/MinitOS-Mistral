# K2 executed evidence

Copies of the CI evidence produced by GitHub Actions workflow "k2",
run #5, on commit 05e614f3 (branch ci/evidence/k2/5). The run installed
clang 18.1.3 / LLVM 18.1.3, GNU binutils 2.42, Python 3.12.3 and
QEMU 8.2.2 on ubuntu-latest.

| File | Content |
|---|---|
| normal-uart.log | Scenario "normal": full boot diagnostics, controlled WFI idle |
| undef-uart.log | Scenario "undef": UND vector entry through the CPU vector table |
| data-abort-uart.log | Scenario "data-abort": ABT vector entry, DFSR/DFAR, alignment fault |
| elf-check.log | Build log plus static verifier output for all three ELFs (SHA-256) |
| repro-hashes.txt | SHA-256 of two independent clean builds of all three ELFs |
| disassembly-vectors.txt | The 8 vector slots at 0x00000000 |
| disassembly-handlers.txt | Entry wrappers and raw fault triggers |
| linker-map.txt | Link map of the normal profile (stack boundaries, symbols) |
| qemu-platform.log | QEMU version and the integratorcp machine entry |
| 00-versions.log | Exact tool versions of the run |

Cross-checks that tie the evidence together (see docs/K2_ACCEPTANCE.md):
- undef fault_pc 0x00010634 == the UDF address in disassembly-handlers.txt
- data-abort fault_pc 0x00010644 == the unaligned ldr address in the same file
- data-abort dfar 0x00010da5 == the address printed before the fault
- all stack boundaries match the linker map and the runtime prints
