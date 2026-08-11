# Makefile

> Shared build system for the project's bare-metal RISC-V targets: compiles the freestanding cross-toolchain build, links against `linker.ld`, and boots the result in QEMU.

This repo holds a single, minimal `Makefile`. It isn't meant to live inside any one project repo, it's the build recipe every RV64 bare-metal component in this project (starting with `jny`) pulls in and reuses, so the compile/link/run invocation stays identical across all of them instead of drifting copy by copy.

## What it does

The whole file is three variables and three targets:

```make
CC = riscv64-elf-gcc
CFLAGS = -march=rv64gc -mabi=lp64d -mcmodel=medany -nostdlib -ffreestanding -Iinclude
SRCS = $(wildcard src/*.c src/*.s)

compile:
	$(CC) $(CFLAGS) -T linker.ld $(SRCS) -o bin/main.elf

clean:
	rm -f bin/main.elf

run:
	qemu-system-riscv64 -machine virt -bios none -kernel bin/main.elf -nographic
```

### `CC` / `CFLAGS`

- **`riscv64-elf-gcc`** — the bare-metal (ELF) cross compiler installed by [`env.sh`](https://github.com/Emilia-Systems/env.sh), not the host's native `gcc`.
- **`-march=rv64gc`** — targets the base RV64I integer ISA plus the `G` (IMAFD: integer mul/div, atomics, single- and double-precision float) and `C` (compressed instructions) extensions. This has to match what the hardware/QEMU actually implements, code built for extensions the target doesn't have will trap.
- **`-mabi=lp64d`** — the calling convention: `long`/pointers are 64-bit, and floating-point arguments are passed in FPU registers (the `d` = double-precision hard-float ABI). Must agree with `-march` including `F`/`D`, mismatching the ABI and ISA is a common source of silent miscompilation.
- **`-mcmodel=medany`** — "medium, any": code and data can be linked anywhere in a ±2 GiB window without assuming a fixed load address near zero. Bare-metal images placed at `0x80000000` (see [`linker.ld`](https://github.com/Emilia-Systems/linker.ld)) need this; the default `medlow` model assumes the low 2 GiB and would generate broken addressing.
- **`-nostdlib`** — don't link libc, libgcc's runtime startup, or the default CRT objects. There's no OS underneath to provide them, and pulling them in would silently drag in code (like `_start` expecting an `argv`/`envp` a hosted OS would set up) that doesn't make sense on bare metal.
- **`-ffreestanding`** — tells GCC this is a freestanding environment: `main` isn't guaranteed to be the entry point, standard library functions aren't assumed to exist, and the compiler won't assume hosted semantics (e.g. it won't optimize a loop into a `memset` call expecting a libc that isn't there).
- **`-Iinclude`** — adds a local `include/` directory to the header search path, this is where per-project headers pulled from repos like [`csr.h`](https://github.com/Emilia-Systems/csr.h), [`extensions.h`](https://github.com/Emilia-Systems/extensions.h), and [`gprintf.h`](https://github.com/Emilia-Systems/gprintf.h) end up.

### `SRCS`

`$(wildcard src/*.c src/*.s)` picks up every `.c` and `.s` file under `src/` automatically, so adding a new source file doesn't require touching this `Makefile`. The trade-off: there's no per-object compilation and no header dependency tracking, every `make compile` recompiles and relinks everything from scratch. That's a deliberate simplification for this stage of the project (see **Known limitations** below), not an oversight.

### `compile`

A single `$(CC)` invocation compiles and links `$(SRCS)` in one step against `-T linker.ld`, the linker script that places `_start` at the base of RAM and lays out `.text`/`.rodata`/`.data`/`.bss` (see the [`linker.ld`](https://github.com/Emilia-Systems/linker.ld) repo for the full breakdown). Output is `bin/main.elf`.

### `clean`

Removes `bin/main.elf`. Nothing else is generated, so there's nothing else to remove yet.

### `run`

```bash
qemu-system-riscv64 -machine virt -bios none -kernel bin/main.elf -nographic
```

- **`-machine virt`** — QEMU's generic RISC-V board, the same memory map `linker.ld` is written against.
- **`-bios none`** — skips the default OpenSBI firmware QEMU would otherwise load first. Without it, our own `_start` (via `ENTRY(_start)` in `linker.ld`) is the literal first instruction executed, matching the M-mode, no-BIOS model this project targets.
- **`-kernel bin/main.elf`** — QEMU loads the ELF directly into RAM and jumps to its entry point; there's no bootloader stage doing that yet.
- **`-nographic`** — redirects the serial console to the terminal instead of opening a display window, since there's no framebuffer or display driver at this stage.

## Requirements

- `riscv64-elf-gcc` / `riscv64-elf-binutils` and `qemu-system-riscv`, both installed by [`env.sh`](https://github.com/Emilia-Systems/env.sh)
- A `linker.ld` at the repo root (from [`linker.ld`](https://github.com/Emilia-Systems/linker.ld))
- `src/` (and optionally `include/`) populated by the consuming project

This `Makefile` doesn't provide any of those itself, it assumes they're already in place.

## Usage

Pulled into a project repo alongside `linker.ld` and any needed headers:

```bash
make compile # build bin/main.elf
make run # boot it in QEMU
make clean # remove the built ELF
```

## Why this is its own repo

This project keeps shared, non-source infrastructure (`env.sh`, `linker.ld`, `Makefile`, headers like `csr.h`) as single-purpose repos rather than duplicating them into every consumer. Other repos declare what they need in a `puller.toml`, and [`pff`](https://github.com/Emilia-Systems/pff) pulls the files straight from source, no submodules, no package registry. This repo's `pulled.toml` is what makes that possible:

```toml
[setup]
files = [
    ["./Makefile", "./"],
]
```

It declares that `./Makefile` is a file this repo exposes for other repos to pull, and where it lands (`./`, the consumer's root) when they do. One canonical build recipe, reused everywhere it's needed, changes propagate by re-pulling instead of copy-pasting.

## Known limitations (intentional, for this stage)

- **No incremental builds.** Every `make compile` rebuilds and relinks every source file; there's no per-object compilation or header dependency tracking. Fine while the source tree is small, this will need real object-file rules once it isn't.
- **Single hardcoded target.** `-march=rv64gc` / `-machine virt` assume one target: QEMU's `virt` machine. Once the project moves to its own FPGA SoC, this will need to become parameterized rather than fixed.
- **No test/debug targets.** No `gdb` integration (`riscv64-elf-gdb`, installed by `env.sh`, isn't wired in here) and no automated test running yet.

These will be revisited as the project grows past a single QEMU target.

## Status

Early stage. This `README` and the `Makefile` itself will be updated as the project's build requirements grow, especially once FPGA targets and multiple images enter the picture.
