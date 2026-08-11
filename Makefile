CC = riscv64-unknown-elf-gcc
CFLAGS = -march=rv64gc -mabi=lp64d -nostdlib -ffreestanding -Iinclude
SRCS = $(wildcard src/*.c src/*.S)

compile:
	$(CC) $(CFLAGS) -T linker.ld $(SRCS) -o bin/main.elf

clean:
	rm -f bin/main.elf

run:
	qemu-system-riscv64 -machine virt -kernel bin/main.elf -nographic