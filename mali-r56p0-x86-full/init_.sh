#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

echo "============================================================"
echo " Mali r56p0 x86 research workspace bootstrap"
echo "============================================================"
echo "[+] Workspace: $ROOT_DIR"
echo

if ! command -v apt-get >/dev/null 2>&1; then
    echo "[!] This script requires an apt-based distribution."
    echo "    Supported: Debian / Kali / Ubuntu"
    exit 1
fi

echo "[+] Installing required packages..."

$SUDO apt-get update

$SUDO apt-get install -y \
    build-essential \
    bc \
    bison \
    flex \
    gcc \
    g++ \
    make \
    git \
    wget \
    curl \
    ca-certificates \
    xz-utils \
    zstd \
    cpio \
    rsync \
    kmod \
    fakeroot \
    pkg-config \
    libssl-dev \
    libelf-dev \
    libdw-dev \
    libncurses-dev \
    dwarves \
    python3 \
    python3-pip \
    gdb \
    gdb-multiarch \
    qemu-system-x86 \
    qemu-utils \
    busybox-static \
    file \
    unzip \
    zip \
    patch \
    xxd

echo
echo "[+] Creating directory structure..."

mkdir -p \
    "$ROOT_DIR/kernel/.downloads" \
    "$ROOT_DIR/driver/.downloads" \
    "$ROOT_DIR/patches" \
    "$ROOT_DIR/qemu" \
    "$ROOT_DIR/rootfs" \
    "$ROOT_DIR/logs" \
    "$ROOT_DIR/tools" \
    "$ROOT_DIR/artifacts"

cat > "$ROOT_DIR/.gitignore" <<'EOF'
# Linux kernel versions
kernel/*/src/
kernel/*/build/
kernel/*/logs/
kernel/*/artifacts/
kernel/.downloads/

# Mali driver versions
driver/*/src/
driver/*/build/
driver/*/logs/
driver/*/artifacts/
driver/.downloads/

# Runtime/generated files
qemu/
rootfs/
artifacts/
logs/

# Build products
*.o
*.ko
*.cmd
*.d
*.a
*.mod
*.mod.c
Module.symvers
modules.order
EOF

cat > "$ROOT_DIR/workspace.env" <<EOF
export MALI_RESEARCH_ROOT="$ROOT_DIR"
export KERNEL_ROOT="$ROOT_DIR/kernel"
export DRIVER_ROOT="$ROOT_DIR/driver"
export PATCH_ROOT="$ROOT_DIR/patches"
export QEMU_ROOT="$ROOT_DIR/qemu"
export ROOTFS_ROOT="$ROOT_DIR/rootfs"
EOF

echo
echo "[+] Checking installed tools..."

for TOOL in gcc make git wget tar xz gdb qemu-system-x86_64 busybox; do
    if command -v "$TOOL" >/dev/null 2>&1; then
        echo "    [OK] $TOOL -> $(command -v "$TOOL")"
    else
        echo "    [!!] $TOOL -> NOT FOUND"
    fi
done

echo
echo "============================================================"
echo "[+] Bootstrap complete"
echo "============================================================"
echo
echo "Workspace:"
echo "  $ROOT_DIR"
echo
echo "Build Linux 6.18.55:"
echo "  ./kernel/build_kernel.sh 6.18.55"
echo
echo "Build another version independently:"
echo "  ./kernel/build_kernel.sh 6.12.111"
echo
echo "Each kernel is isolated under:"
echo "  ./kernel/<version>/"
echo
