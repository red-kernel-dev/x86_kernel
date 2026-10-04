# Mali r56p0 x86 research workspace

This workspace keeps the Linux kernel and Mali r56p0 driver separate.

## 1. Bootstrap

```bash
./init_.sh
```

The bootstrap installs the host packages required for:

- Linux kernel compilation
- external kernel modules
- KASAN/KCOV/UBSAN research
- DWARF/GDB debugging
- QEMU x86_64 virtualization
- initramfs/BusyBox work

It also creates the directory structure.

## 2. Build a kernel

```bash
./kernel/build_kernel.sh 6.18.55
```

The version is an argument, so multiple kernel versions stay isolated.

For example:

```text
kernel/
├── .downloads/
│
├── 6.18.55/
│   ├── src/
│   │   └── linux-6.18.55/
│   ├── build/
│   ├── logs/
│   └── artifacts/
│
└── 6.12.111/
    ├── src/
    │   └── linux-6.12.111/
    ├── build/
    ├── logs/
    └── artifacts/
```

The source and `O=` build directory are separate.

## 3. Kernel artifacts

After a successful build:

```text
kernel/6.18.55/artifacts/
├── bzImage
├── vmlinux
├── Module.symvers
├── System.map
└── config
```

The important files for the later external Mali build are:

```text
KERNEL_SRC:
kernel/6.18.55/src/linux-6.18.55

KERNEL_BUILD:
kernel/6.18.55/build
```

## 4. Build another kernel without touching the first

```bash
./kernel/build_kernel.sh 6.12.111
```

The 6.12.111 build has its own:

- source
- .config
- build output
- Module.symvers
- vmlinux
- bzImage
- logs
- artifacts

## 5. Parallel build

```bash
JOBS=8 ./kernel/build_kernel.sh 6.18.55
```

Default is:

```bash
JOBS=$(nproc)
```

## 6. GDB/QEMU

After the kernel exists:

```bash
./qemu/boot_kernel_gdb.sh 6.18.55
```

QEMU starts paused with:

```text
-gdb tcp::1234
-S
```

In another terminal:

```bash
gdb kernel/6.18.55/artifacts/vmlinux
```

Then:

```gdb
target remote :1234
```

This is a debugging boot target. A root filesystem/initramfs will be added in the next stage.

## 7. Mali driver

The Mali driver is intentionally NOT copied into the Linux source tree.

Later it will be built externally against:

```text
kernel/<VERSION>/src/linux-<VERSION>
kernel/<VERSION>/build
```

This allows us to keep one stable kernel and rapidly rebuild/reload different r56p0 driver revisions.
