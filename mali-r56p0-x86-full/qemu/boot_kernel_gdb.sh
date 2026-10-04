#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-6.18.55}"

KERNEL="$ROOT_DIR/kernel/$VERSION/artifacts/bzImage"

if [[ ! -f "$KERNEL" ]]; then
    echo "[!] Kernel not found:"
    echo "    $KERNEL"
    echo
    echo "Build it first:"
    echo "    $ROOT_DIR/kernel/build_kernel.sh $VERSION"
    exit 1
fi

exec qemu-system-x86_64 \
    -machine pc \
    -m 4096 \
    -smp 4 \
    -kernel "$KERNEL" \
    -append "console=ttyS0 nokaslr" \
    -nographic \
    -no-reboot \
    -monitor none \
    -gdb tcp::1234 \
    -S
