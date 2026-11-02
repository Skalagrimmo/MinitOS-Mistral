# MinitOS K2 — build for the QEMU integratorcp reference machine.
#
# Three build profiles (TZ section 6): normal, undef, data-abort.
# Toolchain: clang/lld with the ARM backend, freestanding, no libc,
# no libgcc, no runtime helpers (checked by tools/verify_elf.py).

TARGET      := arm-none-eabi
BUILD       := build
ENTRY_ADDR  := 0x00010000
SCENARIO    ?= normal

CC      := clang
OBJCOPY  := llvm-objcopy
OBJDUMP  := llvm-objdump
READELF  := readelf
PYTHON   := python3

ARCH_FLAGS := --target=$(TARGET) -mcpu=arm1136jf-s -marm -mfloat-abi=soft
COMMON     := $(ARCH_FLAGS) -ffreestanding -fno-builtin -fno-stack-protector -fno-pic -fno-pie
CFLAGS     := $(COMMON) -std=c11 -O2 -g -Iinclude -Wall -Wextra -Werror
ASFLAGS    := $(COMMON)
LDFLAGS    := $(ARCH_FLAGS) -nostdlib -static -fuse-ld=lld -Wl,-T,linker/integratorcp.ld -Wl,--build-id=none

COMMON_OBJS := \
	$(BUILD)/boot/start.o \
	$(BUILD)/exceptions/vectors.o \
	$(BUILD)/exceptions/handlers.o \
	$(BUILD)/drivers/pl011.o \
	$(BUILD)/tests/faults.o \
	$(BUILD)/tests/scenarios.o

SCENARIOS := normal undef data-abort

ELFS := $(SCENARIOS:%=$(BUILD)/minitos-k2-%.elf)
BINS := $(SCENARIOS:%=$(BUILD)/minitos-k2-%.bin)

.PHONY: all verify disasm run info clean

all: $(ELFS) $(BINS)

$(BUILD):
	mkdir -p $@

$(BUILD)/%.o: src/%.S | $(BUILD)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/%.o: src/%.c | $(BUILD)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Scenario profiles differ only in the kmain dispatch constant.
$(BUILD)/main-normal.o: src/kernel/main.c | $(BUILD)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -DMINIT_TEST_SCENARIO=0 -c $< -o $@

$(BUILD)/main-undef.o: src/kernel/main.c | $(BUILD)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -DMINIT_TEST_SCENARIO=1 -c $< -o $@

$(BUILD)/main-data-abort.o: src/kernel/main.c | $(BUILD)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -DMINIT_TEST_SCENARIO=2 -c $< -o $@

$(BUILD)/minitos-k2-normal.elf: $(COMMON_OBJS) $(BUILD)/main-normal.o linker/integratorcp.ld
	$(CC) $(LDFLAGS) $(COMMON_OBJS) $(BUILD)/main-normal.o -Wl,-Map,$(BUILD)/minitos-k2-normal.map -o $@

$(BUILD)/minitos-k2-undef.elf: $(COMMON_OBJS) $(BUILD)/main-undef.o linker/integratorcp.ld
	$(CC) $(LDFLAGS) $(COMMON_OBJS) $(BUILD)/main-undef.o -Wl,-Map,$(BUILD)/minitos-k2-undef.map -o $@

$(BUILD)/minitos-k2-data-abort.elf: $(COMMON_OBJS) $(BUILD)/main-data-abort.o linker/integratorcp.ld
	$(CC) $(LDFLAGS) $(COMMON_OBJS) $(BUILD)/main-data-abort.o -Wl,-Map,$(BUILD)/minitos-k2-data-abort.map -o $@

$(BUILD)/minitos-k2-%.bin: $(BUILD)/minitos-k2-%.elf
	$(OBJCOPY) -O binary $< $@

verify: all
	$(READELF) -h $(BUILD)/minitos-k2-normal.elf | grep -E 'Class:.*ELF32|Machine:.*ARM|Entry point address:'
	$(READELF) -h $(BUILD)/minitos-k2-normal.elf | grep -E 'Flags:'
	$(READELF) -l $(BUILD)/minitos-k2-normal.elf | grep -E 'LOAD'
	$(READELF) -s $(BUILD)/minitos-k2-normal.elf | grep -E '_start|kmain|minit_exception_dispatch|_vector_table'
	@for s in $(SCENARIOS); do \
		echo "== verify $$s =="; \
		$(PYTHON) tools/verify_elf.py $(BUILD)/minitos-k2-$$s.elf $(ENTRY_ADDR); \
	done
	@echo 'K2 VERIFY: PASS'

disasm: all
	$(OBJDUMP) -d --triple=arm-none-eabi $(BUILD)/minitos-k2-normal.elf > $(BUILD)/disassembly-full.txt
	$(OBJDUMP) -d --triple=arm-none-eabi -j .vectors $(BUILD)/minitos-k2-normal.elf > $(BUILD)/disassembly-vectors.txt
	$(OBJDUMP) -d --triple=arm-none-eabi --disassemble-symbols=minit_vec_reset,minit_entry_und,minit_entry_svc,minit_entry_pabt,minit_entry_dabt,minit_entry_reserved,minit_entry_irq,minit_entry_fiq,minit_test_trigger_undef,minit_test_trigger_data_abort $(BUILD)/minitos-k2-normal.elf > $(BUILD)/disassembly-handlers.txt

run: $(BUILD)/minitos-k2-$(SCENARIO).elf
	SCENARIO=$(SCENARIO) sh scripts/run-qemu.sh

info:
	@echo '--- tool versions ---'
	$(CC) --version | head -n 1
	$(OBJDUMP) --version | head -n 1
	$(OBJCOPY) --version | head -n 1
	$(READELF) --version | head -n 1
	$(PYTHON) --version
	qemu-system-arm --version | head -n 1

clean:
	rm -rf $(BUILD)
