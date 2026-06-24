#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# qemu-test.sh - 一键 QEMU 测试 Orange Pi 内核
#
# 📖 说明:
#   编译 ARM64 busybox → 创建 initramfs → 启动 QEMU
#   全部自动化，无需手动操作。
#
# 用法:
#   ./scripts/qemu-test.sh              # 完整流程
#   ./scripts/qemu-test.sh --kernel     # 只启动 QEMU (需要已有 initramfs)
#   ./scripts/qemu-test.sh --help       # 查看帮助
#
# 退出 QEMU: Ctrl+A, 然后按 X
#

set -e

KERNEL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INITRAMFS_DIR="/tmp/initramfs-arm64"
INITRAMFS_FILE="/tmp/initramfs-arm64.cpio.gz"
BUSYBOX_DIR="/tmp/busybox-1.36.1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================
# 检查依赖
# =============================================
check_deps() {
    local missing=0

    command -v qemu-system-aarch64 >/dev/null 2>&1 || {
        warn "需要安装: sudo apt install qemu-system-arm"
        missing=1
    }

    command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || {
        warn "需要安装: sudo apt install gcc-aarch64-linux-gnu"
        missing=1
    }

    command -v cpio >/dev/null 2>&1 && missing=1

    if [ $missing -eq 1 ]; then
        info "请安装依赖后重试"
        exit 1
    fi
}

# =============================================
# 确认内核 Image 存在
# =============================================
check_kernel() {
    if [ ! -f "$KERNEL_DIR/arch/arm64/boot/Image" ]; then
        error "找不到内核镜像!"
        error "请先编译内核:"
        error "  cd $KERNEL_DIR"
        error "  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- orangepi_defconfig"
        error "  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j\$(nproc) Image"
        exit 1
    fi
    info "内核镜像: $KERNEL_DIR/arch/arm64/boot/Image ($(du -h $KERNEL_DIR/arch/arm64/boot/Image | cut -f1))"
}

# =============================================
# 编译 ARM64 busybox
# =============================================
build_busybox() {
    if [ -f "$BUSYBOX_DIR/busybox" ] && [ -x "$BUSYBOX_DIR/busybox" ]; then
        info "Busybox 已编译，跳过"
        return
    fi

    info "下载 busybox 源码..."
    mkdir -p /tmp
    cd /tmp

    if [ ! -f busybox-1.36.1.tar.bz2 ]; then
        wget -q https://busybox.net/downloads/busybox-1.36.1.tar.bz2
    fi

    if [ ! -d "$BUSYBOX_DIR" ]; then
        tar xf busybox-1.36.1.tar.bz2
    fi

    cd "$BUSYBOX_DIR"

    info "配置 busybox..."
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig >/dev/null 2>&1

    # 启用静态编译
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

    # 禁用与新 GCC 不兼容的 tc 工具
    sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config

    info "编译 busybox (ARM64)..."
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) 2>&1 | tail -1
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CONFIG_PREFIX="$INITRAMFS_DIR" install >/dev/null 2>&1

    info "Busybox 编译完成: $(file $INITRAMFS_DIR/bin/busybox)"
}

# =============================================
# 创建 initramfs
# =============================================
build_initramfs() {
    info "创建 initramfs..."

    # 创建目录结构
    mkdir -p "$INITRAMFS_DIR"/{bin,dev,etc,proc,sys,tmp}
    cp "$BUSYBOX_DIR/_install/bin/busybox" "$INITRAMFS_DIR/bin/" 2>/dev/null || \
        cp "$BUSYBOX_DIR/busybox" "$INITRAMFS_DIR/bin/busybox"

    # 创建 init 脚本
    cat > "$INITRAMFS_DIR/init" << 'INITEOF'
#!/bin/busybox sh

# 挂载虚拟文件系统
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev

# 安装 busybox 符号链接
/bin/busybox --install -s /bin

# 显示欢迎信息
echo ""
echo "============================================"
echo "  🍊 Orange Pi Kernel - QEMU Test PASSED!"
echo "============================================"
echo ""
echo "内核版本: $(cat /proc/version)"
echo "CPU 核心: $(grep -c processor /proc/cpuinfo)"
echo "内存总量: $(grep MemTotal /proc/meminfo | awk '{print $2 " " $3}')"
echo ""
echo "可用命令: ls, cat, ps, mount, dmesg, uname, free"
echo "退出 QEMU: Ctrl+A 松开后按 X"
echo ""

# 启动 shell
exec /bin/sh
INITEOF
    chmod +x "$INITRAMFS_DIR/init"

    # 打包为 cpio.gz
    cd "$INITRAMFS_DIR"
    find . | cpio -o --format=newc 2>/dev/null | gzip -9 > "$INITRAMFS_FILE"

    info "Initramfs 创建完成: $INITRAMFS_FILE ($(du -h $INITRAMFS_FILE | cut -f1))"
}

# =============================================
# 启动 QEMU
# =============================================
run_qemu() {
    if [ ! -f "$INITRAMFS_FILE" ]; then
        error "找不到 initramfs: $INITRAMFS_FILE"
        error "请先运行: $0"
        exit 1
    fi

    info "启动 QEMU (按 Ctrl+A 松开后按 X 退出)..."
    echo ""

    cd "$KERNEL_DIR"
    qemu-system-aarch64 \
        -machine virt \
        -cpu cortex-a53 \
        -m 256M \
        -kernel arch/arm64/boot/Image \
        -initrd "$INITRAMFS_FILE" \
        -append "console=ttyAMA0" \
        -nographic \
        -no-reboot
}

# =============================================
# 帮助信息
# =============================================
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  (无参数)    完整流程: 编译 busybox → 创建 initramfs → 启动 QEMU"
    echo "  --kernel    只启动 QEMU (需要已有 initramfs)"
    echo "  --help      显示此帮助"
    echo ""
    echo "前置条件:"
    echo "  1. 已配置交叉编译器: gcc-aarch64-linux-gnu"
    echo "  2. 已安装 QEMU: qemu-system-arm"
    echo "  3. 已编译内核: make ... Image"
}

# =============================================
# 主流程
# =============================================
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --kernel)
        check_kernel
        run_qemu
        ;;
    "")
        check_deps
        check_kernel
        build_busybox
        build_initramfs
        run_qemu
        ;;
    *)
        error "未知选项: $1"
        show_help
        exit 1
        ;;
esac
