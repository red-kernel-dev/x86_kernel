#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# build_kernel.sh
#
# Build an isolated x86_64 Linux kernel version.
#
# Usage:
#   ./build_kernel.sh 6.18.55
#
# Optional:
#   JOBS=8 ./build_kernel.sh 6.18.55
#
# Layout:
#
# kernel/
# ├── build_kernel.sh
# ├── .downloads/
# │   └── linux-6.18.55.tar.xz
# │
# └── 6.18.55/
#     ├── src/
#     │   └── linux-6.18.55/
#     ├── build/
#     ├── logs/
#     │   └── build.log
#     └── artifacts/
#         ├── bzImage
#         ├── vmlinux
#         ├── System.map
#         ├── Module.symvers
#         └── config
#
# IMPORTANT:
# Mali r56p0 is NOT copied into the kernel tree.
# It will later be built as an external module.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <kernel-version>"
    echo
    echo "Example:"
    echo "  $0 6.18.55"
    exit 2
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[!] Invalid kernel version: $VERSION"
    echo "[!] Expected format: X.Y.Z"
    exit 2
fi

JOBS="${JOBS:-$(nproc)}"

VERSION_DIR="$SCRIPT_DIR/$VERSION"
SRC_ROOT="$VERSION_DIR/src"
BUILD_DIR="$VERSION_DIR/build"
LOG_DIR="$VERSION_DIR/logs"
ARTIFACT_DIR="$VERSION_DIR/artifacts"
DOWNLOAD_DIR="$SCRIPT_DIR/.downloads"

SRC_DIR="$SRC_ROOT/linux-$VERSION"
ARCHIVE="$DOWNLOAD_DIR/linux-$VERSION.tar.xz"

# Linux 6.x releases are available here.
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$VERSION.tar.xz"

mkdir -p \
    "$SRC_ROOT" \
    "$BUILD_DIR" \
    "$LOG_DIR" \
    "$ARTIFACT_DIR" \
    "$DOWNLOAD_DIR"

LOG_FILE="$LOG_DIR/build.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo " Linux kernel isolated build"
echo "============================================================"
echo "Version    : $VERSION"
echo "Source     : $SRC_DIR"
echo "Build      : $BUILD_DIR"
echo "Artifacts  : $ARTIFACT_DIR"
echo "Logs       : $LOG_DIR"
echo "Jobs       : $JOBS"
echo "============================================================"
echo

# ------------------------------------------------------------
# Download source
# ------------------------------------------------------------

if [[ ! -f "$ARCHIVE" ]]; then
    echo "[+] Downloading:"
    echo "    $KERNEL_URL"

    wget \
        --continue \
        -O "$ARCHIVE.tmp" \
        "$KERNEL_URL"

    mv "$ARCHIVE.tmp" "$ARCHIVE"
else
    echo "[+] Archive already exists:"
    echo "    $ARCHIVE"
fi

# ------------------------------------------------------------
# Extract source
# ------------------------------------------------------------

if [[ ! -d "$SRC_DIR" ]]; then
    echo "[+] Extracting source..."

    tar \
        -xf "$ARCHIVE" \
        -C "$SRC_ROOT"
else
    echo "[+] Source already extracted."
fi

# ------------------------------------------------------------
# Verify source version
# ------------------------------------------------------------

cd "$SRC_DIR"

ACTUAL_VERSION="$(make -s kernelversion)"

if [[ "$ACTUAL_VERSION" != "$VERSION" ]]; then
    echo
    echo "[!] Kernel source version mismatch!"
    echo "    requested: $VERSION"
    echo "    actual:    $ACTUAL_VERSION"
    exit 1
fi

echo "[+] Kernel version verified: $ACTUAL_VERSION"

# ------------------------------------------------------------
# Create x86_64 base configuration
# ------------------------------------------------------------

echo
echo "[+] Creating x86_64 defconfig..."

make \
    O="$BUILD_DIR" \
    ARCH=x86_64 \
    defconfig

CONFIG="$BUILD_DIR/.config"

# ------------------------------------------------------------
# Enable research/debug/fuzzing facilities
# ------------------------------------------------------------

echo
echo "[+] Configuring research kernel..."

scripts/config \
    --file "$CONFIG" \
    --enable CONFIG_64BIT \
    --enable CONFIG_X86_64 \
    --enable CONFIG_MODULES \
    --enable CONFIG_MODULE_UNLOAD \
    --enable CONFIG_DEVTMPFS \
    --enable CONFIG_DEVTMPFS_MOUNT \
    --enable CONFIG_KCOV \
    --enable CONFIG_KASAN \
    --enable CONFIG_KASAN_GENERIC \
    --enable CONFIG_UBSAN \
    --enable CONFIG_DEBUG_INFO \
    --enable CONFIG_DEBUG_INFO_DWARF5 \
    --enable CONFIG_GDB_SCRIPTS \
    --enable CONFIG_FRAME_POINTER \
    --enable CONFIG_KALLSYMS \
    --enable CONFIG_KALLSYMS_ALL \
    --enable CONFIG_DEBUG_KERNEL \
    --enable CONFIG_DEBUG_FS \
    --enable CONFIG_MAGIC_SYSRQ \
    --enable CONFIG_STACKTRACE \
    --enable CONFIG_SLUB_DEBUG \
    --enable CONFIG_SLUB_DEBUG_ON \
    --disable CONFIG_RANDOMIZE_BASE

# ------------------------------------------------------------
# Normalize configuration
# ------------------------------------------------------------

echo
echo "[+] Normalizing .config..."

make \
    O="$BUILD_DIR" \
    ARCH=x86_64 \
    olddefconfig

# Save exact configuration used.
cp \
    "$CONFIG" \
    "$ARTIFACT_DIR/config"

# ------------------------------------------------------------
# Display important options
# ------------------------------------------------------------

echo
echo "[+] Important configuration:"

grep -E \
    '^CONFIG_(64BIT|X86_64|MODULES|MODULE_UNLOAD|DEVTMPFS|DEVTMPFS_MOUNT|KCOV|KASAN|KASAN_GENERIC|UBSAN|DEBUG_INFO|DEBUG_INFO_DWARF5|GDB_SCRIPTS|FRAME_POINTER|KALLSYMS|KALLSYMS_ALL|DEBUG_KERNEL|DEBUG_FS|MAGIC_SYSRQ|STACKTRACE|SLUB_DEBUG|SLUB_DEBUG_ON|RANDOMIZE_BASE)=' \
    "$CONFIG" || true

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

echo
echo "[+] Building Linux $VERSION..."
echo "[+] Parallel jobs: $JOBS"
echo

make \
    O="$BUILD_DIR" \
    ARCH=x86_64 \
    -j"$JOBS"

# ------------------------------------------------------------
# Verify build artifacts
# ------------------------------------------------------------

echo
echo "[+] Verifying build artifacts..."

REQUIRED_FILES=(
    "$BUILD_DIR/vmlinux"
    "$BUILD_DIR/arch/x86/boot/bzImage"
    "$BUILD_DIR/Module.symvers"
    "$BUILD_DIR/System.map"
)

for FILE in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$FILE" ]]; then
        echo "[!] Missing required artifact:"
        echo "    $FILE"
        exit 1
    fi
done

# ------------------------------------------------------------
# Copy stable artifacts
# ------------------------------------------------------------

echo "[+] Copying stable artifacts..."

cp \
    "$BUILD_DIR/vmlinux" \
    "$ARTIFACT_DIR/vmlinux"

cp \
    "$BUILD_DIR/arch/x86/boot/bzImage" \
    "$ARTIFACT_DIR/bzImage"

cp \
    "$BUILD_DIR/Module.symvers" \
    "$ARTIFACT_DIR/Module.symvers"

cp \
    "$BUILD_DIR/System.map" \
    "$ARTIFACT_DIR/System.map"

# ------------------------------------------------------------
# Basic validation
# ------------------------------------------------------------

echo
echo "[+] Validating vmlinux..."

file "$ARTIFACT_DIR/vmlinux"

echo
echo "[+] Validating bzImage..."

file "$ARTIFACT_DIR/bzImage"

echo
echo "[+] Checking DWARF debug sections..."

if readelf -S "$ARTIFACT_DIR/vmlinux" 2>/dev/null | grep -q '\.debug_info'; then
    echo "    [OK] DWARF debug information present"
else
    echo "    [WARN] .debug_info not found"
fi

echo
echo "============================================================"
echo " BUILD SUCCESS"
echo "============================================================"
echo
echo "Kernel version:"
echo "  $VERSION"
echo
echo "Source:"
echo "  $SRC_DIR"
echo
echo "Build directory:"
echo "  $BUILD_DIR"
echo
echo "bzImage:"
echo "  $ARTIFACT_DIR/bzImage"
echo
echo "vmlinux:"
echo "  $ARTIFACT_DIR/vmlinux"
echo
echo "Module.symvers:"
echo "  $ARTIFACT_DIR/Module.symvers"
echo
echo "Kernel config:"
echo "  $ARTIFACT_DIR/config"
echo
echo "Build log:"
echo "  $LOG_FILE"
echo
echo "============================================================"
echo
echo "External Mali driver should later use:"
echo
echo "  KERNEL_SRC=$SRC_DIR"
echo "  KERNEL_BUILD=$BUILD_DIR"
echo
echo "============================================================"
