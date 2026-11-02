# MinitOS K1 — build for QEMU integratorcp (ARMv6 / ARM1136).

TARGET      := arm-none-eabi
CC          ?= clang
OBJCOPY     ?= llvm-objcopy
OBJDUMP     ?= llvm-objdump
READELF     ?= readelf
PYTHON      ?= python3

BUILD       := build
ELF         := $(BUILD)/minitos-k1.elf
BIN         := $(BUILD)/minitos-k1.bin
MAP         := $(BUILD)/minitos-k1.map
ENTRY_ADDR  := 0x00010000

ARCH_FLAGS  := --target=$(TARGET) -mcpu=arm1136jf-s -marm -mfloat-abi=soft
COMMON      := $(ARCH_FLAGS) -ffreestanding -fno-builtin -fno-stack-protector \
               -fno-pic -fno-pie -fno-common -fno-unwind-tables \
               -fno-asynchronous-unwind-tables
CFLAGS      := $(COMMON) -std=c11 -O2 -g -Iinclude -Wall -Wextra -Werror
ASFLAGS     := $(COMMON)
LDFLAGS     := $(ARCH_FLAGS) -nostdlib -static -fuse-ld=lld \
               -Wl,-T,linker/integratorcp.ld \
               -Wl,-Map,$(MAP) -Wl,--build-id=none

OBJS        := $(BUILD)/boot/start.o $(BUILD)/drivers/pl011.o $(BUILD)/kernel/main.o

.PHONY: all verify run disasm info clean

all: $(ELF) $(BIN)

$(BUILD):
	mkdir -p $@

$(BUILD)/%.o: src/%.S
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/%.o: src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS) linker/integratorcp.ld
	$(CC) $(LDFLAGS) $(OBJS) -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

verify: all
	$(READELF) -h $(ELF) | grep -E 'Class:.*ELF32|Machine:.*ARM|Entry point address:'
	$(READELF) -l $(ELF) | grep -E 'LOAD'
	$(READELF) -s $(ELF) | grep -E '_start|kmain|__stack_top__'
	$(PYTHON) tools/verify_elf.py $(ELF) $(ENTRY_ADDR)
	@echo 'K1 VERIFY: PASS'

run: all
	sh scripts/run-qemu.sh

disasm: all
	$(OBJDUMP) -d --triple=arm-none-eabi $(ELF) > $(BUILD)/disassembly.txt

info:
	$(CC) --version | head -1
	$(OBJCOPY) --version | head -1
	$(OBJDUMP) --version | head -1
	$(READELF) --version | head -1
	qemu-system-arm --version | head -1

clean:
	rm -rf $(BUILD)
