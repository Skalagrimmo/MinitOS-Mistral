#!/bin/sh
# MinitOS K2 — run one scenario in QEMU, capture UART, stop at marker.
#
# usage: k2-harness.sh <elf> <marker> <uart-log> [timeout_seconds]
#
# Exits 0 only if the marker was actually observed in the UART log.
# The QEMU process is killed explicitly in every path. A hang with no
# output is a FAILURE, never a success (TZ section 6).

set -u

ELF="$1"
MARKER="$2"
LOG="$3"
TIMEOUT="${4:-20}"

QEMU="${QEMU:-qemu-system-arm}"

: > "$LOG"

QEMU_AUDIO_DRV=none "$QEMU" \
    -M integratorcp -cpu arm1136 -m 128M \
    -display none -serial file:"$LOG" \
    -kernel "$ELF" </dev/null &
QPID=$!

i=0
limit=$((TIMEOUT * 2))
while [ "$i" -lt "$limit" ]; do
    if grep -aq "$MARKER" "$LOG" 2>/dev/null; then
        kill "$QPID" 2>/dev/null
        wait "$QPID" 2>/dev/null
        exit 0
    fi
    sleep 0.5
    i=$((i + 1))
done

kill "$QPID" 2>/dev/null
wait "$QPID" 2>/dev/null
echo "FATAL: marker '$MARKER' not found within ${TIMEOUT}s in $LOG" >&2
exit 1
