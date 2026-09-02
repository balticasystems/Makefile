CC = riscv64-elf-gcc
CFLAGS = -march=rv64gc -mabi=lp64d -mcmodel=medany -nostdlib -ffreestanding -Iinclude
SRCS = $(wildcard src/*.c src/*.s)
BOOLOADER_LD = jny.ld
KERNEL_LD = emilia.ld
LINKER = $(BOOLOADER_LD)

setup:
	mkdir -p bin

compile: setup
	$(CC) $(CFLAGS) -T $(LINKER) $(SRCS) -o bin/main.elf

run: compile
	qemu-system-riscv64 -machine virt -bios none -kernel bin/main.elf -nographic

clean:
	rm -f bin/main.elf
