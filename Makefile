CC = riscv64-elf-gcc
CFLAGS = -march=rv64gc -mabi=lp64d -mcmodel=medany -nostdlib -ffreestanding -Iinclude
#SRCS = $(wildcard src/*.c src/*.s)
JNY_SRCS = $(wildcard src/jny*)
EMILIA_SRCS = $(wildcard src/emilia*)
JNY_LD = jny.ld
EMILIA_LD = emilia.ld
LINKER = $(JNY_LD)

setup:
	mkdir -p bin

# compile: setup
# 	$(CC) $(CFLAGS) -T $(LINKER) $(SRCS) -o bin/main.elf

compile_jny: setup
	$(CC) $(CFLAGS) -T $(JNY_LD) $(JNY_SRCS) -o bin/jny.elf

compile_emilia: setup
	$(CC) $(CFLAGS) -T $(EMILIA_LD) $(EMILIA_SRCS) -o bin/emilia.elf

compile: setup compile_jny compile_emilia

run_jny: compile_jny
	qemu-system-riscv64 -machine virt -bios bin/jny.elf -nographic

run: compile
	qemu-system-riscv64 -machine virt -bios bin/jny.elf -kernel bin/emilia.elf -nographic

clean:
	rm -rf bin/*
