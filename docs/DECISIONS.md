successfully downloaded text file (SHA: 1c0ccf42a9679e888f3c356f81719ae0a0430c23)

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
