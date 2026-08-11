CC = riscv64-elf-gcc
CFLAGS = -march=rv64gc -mabi=lp64d -mcmodel=medany -nostdlib -ffreestanding -Iinclude
SRCS = $(wildcard src/*.c src/*.s)

compile:
	$(CC) $(CFLAGS) -T linker.ld $(SRCS) -o bin/main.elf

clean:
	rm -f bin/main.elf

run:
	qemu-system-riscv64 -machine virt -bios none -kernel bin/main.elf -nographic