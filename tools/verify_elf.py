#!/usr/bin/env python3
"""MinitOS K1 — deterministic sanity checks for the built ELF image.

Checks:
  * ELF32, little-endian, machine ARM (EM_ARM = 40), type ET_EXEC
  * entry point equals the expected K1 entry address (default 0x00010000)
  * entry point lies inside a PT_LOAD segment
  * required symbols (_start, kmain) exist in the static symbol table
  * the required UART banner string is embedded in the image
  * prints the SHA-256 of the ELF (and of the .bin, if present)

This script makes no claim about runtime behaviour; that requires QEMU
and is covered by scripts/run-qemu.sh.
"""
import hashlib
import struct
import sys
from pathlib import Path

PT_LOAD = 1
SHT_SYMTAB = 2


def fail(msg):
    print("VERIFY FAIL: %s" % msg)
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        fail("usage: verify_elf.py <file.elf> [expected_entry_hex]")

    path = Path(sys.argv[1])
    expected_entry = None
    if len(sys.argv) >= 3:
        expected_entry = int(sys.argv[2], 16)

    data = path.read_bytes()

    if data[:4] != b"\x7fELF":
        fail("not an ELF file")
    if data[4] != 1:
        fail("expected ELFCLASS32")
    if data[5] != 1:
        fail("expected little-endian ELF")

    hdr = struct.unpack_from("<16sHHIIIIIHHHHHH", data, 0)
    (_, e_type, e_machine, _, e_entry, e_phoff, e_shoff,
     _, _, e_phentsize, e_phnum, e_shentsize, e_shnum, _) = hdr

    if e_machine != 40:
        fail("expected EM_ARM (40), got %d" % e_machine)
    if e_type != 2:
        fail("expected ET_EXEC (2), got %d" % e_type)
    if expected_entry is not None and e_entry != expected_entry:
        fail("entry 0x%08x != expected 0x%08x" % (e_entry, expected_entry))

    # Entry must be inside a loadable segment.
    inside = False
    for i in range(e_phnum):
        (p_type, _, p_vaddr, _, _, p_memsz, _, _) = struct.unpack_from(
            "<8I", data, e_phoff + i * e_phentsize)
        if p_type == PT_LOAD and p_vaddr <= e_entry < p_vaddr + p_memsz:
            inside = True
            break
    if not inside:
        fail("entry 0x%08x is not inside any PT_LOAD segment" % e_entry)

    # Required symbols.
    symtab = None
    for i in range(e_shnum):
        sh = struct.unpack_from("<10I", data, e_shoff + i * e_shentsize)
        if sh[1] == SHT_SYMTAB:
            symtab = sh
            break
    if symtab is None:
        fail("no symbol table found")

    strtab = struct.unpack_from("<10I", data, e_shoff + symtab[6] * e_shentsize)
    strings = data[strtab[4]:strtab[4] + strtab[5]]

    required = {b"_start", b"kmain"}
    found = set()
    off, end = symtab[4], symtab[4] + symtab[5]
    while off + 16 <= end:
        st_name = struct.unpack_from("<I", data, off)[0]
        nul = strings.find(b"\x00", st_name)
        if nul == -1:
            nul = len(strings)
        name = strings[st_name:nul]
        if name in required:
            found.add(name)
        off += 16
    missing = required - found
    if missing:
        fail("missing symbols: %s" % sorted(n.decode() for n in missing))

    # Required banner must be embedded in the image.
    banner = b"MINITOS KERNEL STARTED"
    if banner not in data:
        fail("banner string %r not found in the ELF" % banner)

    print("ELF32 LE ARM ET_EXEC: PASS")
    print("entry 0x%08x inside PT_LOAD: PASS" % e_entry)
    print("symbols _start, kmain: PASS")
    print("banner string: PASS")
    print("sha256 elf: %s" % hashlib.sha256(data).hexdigest())
    bin_path = path.with_suffix(".bin")
    if bin_path.exists():
        print("sha256 bin: %s" % hashlib.sha256(bin_path.read_bytes()).hexdigest())
    print("K1 ELF VERIFY: PASS")


if __name__ == "__main__":
    main()
