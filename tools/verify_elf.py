#!/usr/bin/env python3
"""MinitOS K2 — deterministic static checks for built ELF images.

Checks (TZ MINITOS-K2-TZ, section 7):
  * ELF32, little-endian, EM_ARM, ET_EXEC, EABI5 e_flags
  * entry equals the expected K2 entry and lies inside a PT_LOAD
  * a dedicated R+E, non-writable vector PT_LOAD at vaddr 0 with exactly
    32 bytes and 8 branch instructions whose targets are inside RAM
  * required symbols present; banked stack tops 8-byte aligned (K2-05)
  * no undefined symbols (no accidental libc/runtime helpers)
  * required UART strings and the UDF encoding 0xE7F000F0 present
  * prints SHA-256 of the ELF (and the BIN when present) for
    reproducibility evidence
"""
import hashlib
import struct
import sys
from pathlib import Path

PT_LOAD = 1
PF_X = 1
PF_W = 2
PF_R = 4
SHT_SYMTAB = 2
SHN_UNDEF = 0
EABI5_MASK = 0xFF000000
EABI5_VALUE = 0x05000000

BRANCH_OPCODE = 0xEA000000
BRANCH_MASK = 0xFF000000
RAM_LIMIT = 0x08000000  # 128 MiB QEMU integratorcp SDRAM

STACK_TOP_SYMBOLS = [
    b"__svc_stack_top__",
    b"__und_stack_top__",
    b"__abt_stack_top__",
    b"__irq_stack_top__",
    b"__fiq_stack_top__",
]

REQUIRED_SYMBOLS = [
    b"_start",
    b"kmain",
    b"_vector_table",
    b"minit_exception_dispatch",
] + STACK_TOP_SYMBOLS

REQUIRED_STRINGS = [
    b"MINITOS KERNEL STARTED",
    b"K2 EXCEPTION CAPTURED",
    b"EXCEPTION: ",
]

UDF_ENCODING = b"\xf0\x00\xf0\xe7"  # .inst 0xE7F000F0, little-endian


def fail(msg):
    print("VERIFY FAIL: %s" % msg)
    sys.exit(1)


def sext24(imm):
    if imm & 0x800000:
        return imm - 0x1000000
    return imm


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
    (_, e_type, e_machine, _, e_entry, e_phoff, e_shoff, e_flags,
     _, e_phentsize, e_phnum, e_shentsize, e_shnum, _) = hdr

    if e_machine != 40:
        fail("expected EM_ARM (40), got %d" % e_machine)
    if e_type != 2:
        fail("expected ET_EXEC (2), got %d" % e_type)
    if (e_flags & EABI5_MASK) != EABI5_VALUE:
        fail("expected EABI5 e_flags 0x05000000, got 0x%08x" % e_flags)
    if expected_entry is not None and e_entry != expected_entry:
        fail("entry 0x%08x != expected 0x%08x" % (e_entry, expected_entry))

    vectors_seg = None
    entry_inside = False
    for i in range(e_phnum):
        (p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz,
         p_flags, p_align) = struct.unpack_from("<8I", data, e_phoff + i * e_phentsize)
        if p_type == PT_LOAD and p_vaddr <= e_entry < p_vaddr + p_memsz:
            entry_inside = True
        if p_type == PT_LOAD and p_vaddr == 0:
            vectors_seg = (p_offset, p_vaddr, p_paddr, p_filesz, p_flags)
    if not entry_inside:
        fail("entry 0x%08x is not inside any PT_LOAD" % e_entry)
    if vectors_seg is None:
        fail("no PT_LOAD found at vaddr 0x00000000 for the vector table")

    v_off, v_vaddr, v_paddr, v_filesz, v_flags = vectors_seg
    if v_filesz != 32:
        fail("vector segment filesz is %d, expected exactly 32" % v_filesz)
    if v_paddr != v_vaddr:
        fail("vector segment p_paddr 0x%08x != p_vaddr 0x%08x" % (v_paddr, v_vaddr))
    if (v_flags & (PF_R | PF_X)) != (PF_R | PF_X):
        fail("vector segment is not R+X")
    if (v_flags & PF_W) != 0:
        fail("vector segment must not be writable")

    for slot in range(8):
        (word,) = struct.unpack_from("<I", data, v_off + slot * 4)
        if (word & BRANCH_MASK) != BRANCH_OPCODE:
            fail("vector slot %d is not an ARM branch: 0x%08x" % (slot, word))
        target = slot * 4 + 8 + (sext24(word & 0xFFFFFF) << 2)
        if not (0 < target < RAM_LIMIT):
            fail("vector slot %d branch target 0x%08x outside RAM" % (slot, target))

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

    values = {}
    undefined = []
    off, end = symtab[4], symtab[4] + symtab[5]
    while off + 16 <= end:
        st_name, st_value, _, _, _, st_shndx = struct.unpack_from("<IIIBBH", data, off)
        if st_name:
            nul = strings.find(b"\x00", st_name)
            if nul == -1:
                nul = len(strings)
            name = bytes(strings[st_name:nul])
            values[name] = st_value
            if st_shndx == SHN_UNDEF:
                undefined.append(name)
        off += 16

    missing = [s for s in REQUIRED_SYMBOLS if s not in values]
    if missing:
        fail("missing symbols: %s" % [m.decode() for m in missing])
    if undefined:
        fail("undefined symbols (missing runtime helpers?): %s" % [u.decode() for u in undefined])
    for sym in STACK_TOP_SYMBOLS:
        if values[sym] % 8 != 0:
            fail("%s = 0x%08x is not 8-byte aligned" % (sym.decode(), values[sym]))

    for s in REQUIRED_STRINGS:
        if s not in data:
            fail("required string %r not found in the image" % s)
    if UDF_ENCODING not in data:
        fail("UDF encoding 0xE7F000F0 not found in the image")

    print("ELF32 LE ARM ET_EXEC EABI5: PASS")
    print("entry 0x%08x inside PT_LOAD: PASS" % e_entry)
    print("vector segment @ 0x00000000, 32 bytes, R+E, 8 branch slots: PASS")
    print("symbols present, banked stack tops 8-byte aligned: PASS")
    print("no undefined symbols: PASS")
    print("required strings and UDF encoding: PASS")
    print("sha256 elf: %s" % hashlib.sha256(data).hexdigest())
    bin_path = path.with_suffix(".bin")
    if bin_path.exists():
        print("sha256 bin: %s" % hashlib.sha256(bin_path.read_bytes()).hexdigest())
    print("K2 ELF VERIFY: PASS")


if __name__ == "__main__":
    main()
