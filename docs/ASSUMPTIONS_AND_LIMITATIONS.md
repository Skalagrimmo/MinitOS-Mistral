# MinitOS K2 — Assumptions and Limitations

Unverified assumptions, observed deviations and hard limits of the K2
stage. Anything not listed as verified here was not verified.

## Platform boundary

- K2 runs only on QEMU (\`-M integratorcp -cpu arm1136 -m 128M\`).
- 0x00000000 as vector base, the 128 MiB RAM map and the PL011 at
  0x16000000 are properties of the QEMU reference machine, verified
  against QEMU sources and by execution — NOT of the Galaxy Gio.
- No Galaxy Gio linker script, boot entry or flashing instructions may
  be derived from K2 addresses. The MSM7227 SoC revision, boot chain,
  SDRAM map, reset vector contract and recovery path are unverified.

## High vectors not used

- High vectors (0xFFFF0000) were NOT proven to be backed by RAM on this
  machine, so K2 uses low vectors (SCTLR.V = 0). This choice is
  deliberate and safe; it is not a claim that high vectors cannot work.

## ELF entry vs reset vector

- QEMU's ELF loader starts at the ELF entry point (0x00010000), not at
  the reset vector. The reset slot still points to _start, but the reset
  path itself was never executed by the accepted runs.

## QEMU-specific observations (not verified on silicon)

- SCTLR reset read-back observed as 0x00050078; after setting U/A the
  read-back was 0x0045007a. These are QEMU model values.
- DFSR for the alignment fault was observed as 0x00000001 on QEMU 8.2.2
  (status in bits [4:0]), which differs from the printed ARM1136 TRM
  layout (FS[3:1] in bits [3:1], FS[0] in bit 10). The handler accepts
  the alignment status in either layout and always prints the raw DFSR;
  a different emulator or real silicon could therefore still be caught
  by the explicit mismatch line instead of a silent false PASS.
- CPSR read-back 0x600001d3: the flag bits (Z, C) come from the last
  startup comparison and are harmless; the mode/I/F bits are the ones
  asserted as evidence.

## Build-profile effects

- The three profiles differ only in the kmain scenario constant, so the
  three ELFs have different sizes and SHA-256; .data/.stacks addresses
  shift by 0x20 between profiles. Authoritative addresses per profile
  are in that profile's linker map and runtime "K2 stack:" lines.
- Reproducibility (K2-13) is asserted only within one toolchain/host —
  pinned versions are recorded in docs/evidence/00-versions.log.
  Cross-compiler reproducibility is explicitly NOT claimed.

## Scope limits (by design, TZ section 9)

- No recovery from exceptions: K2 is fail-stop after diagnostics.
- No instruction emulation, no retry/skip policy, no return to the
  interrupted context.
- No MMU/page tables, no interrupt controller (VIC/PL190), no timer.
- No scheduler, user mode, syscalls or SVC ABI (the SVC slot is a stub).
- IRQ/FIQ remain masked; their stubs were never entered in K2 runs.
- UART: polled TX only; RX not handled.
- Single core, single thread.

## Open issues for later stages

- Verify the exact DFSR encoding against real ARM1136 silicon or a
  reference-accurate model before porting fault policies.
- The vector table occupies the first 32 bytes of RAM; the remaining
  low 64 KiB is reserved and unused — its eventual purpose (e.g. early
  boot structures) is an open decision for K3+.
- The WFI halt relies on masked IRQ/FIQ; once interrupts are enabled,
  the halt loop must be revisited (wakeup sources).
