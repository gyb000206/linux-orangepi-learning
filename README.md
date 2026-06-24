# 🐧 Linux 内核学习项目 — Orange Pi

> **基于 Orange Pi Prime · Allwinner H5 (arm64) · Linux 5.4.65**
>
> 📖 **[👉 完整学习指南点这里](docs/linux-kernel-learning-guide.md)** — 1152 行的新手入门教程

---

## 📋 目录

- [关于这个仓库](#-关于这个仓库)
- [快速开始](#-快速开始)
- [项目结构速览](#-项目结构速览)
- [代码注释清单](#-代码注释清单)
- [QEMU 测试](#-qemu-测试)
- [注意事项](#-注意事项)
- [学习路线建议](#-学习路线建议)
- [相关资源](#-相关资源)

---

## 📌 关于这个仓库

### 这是什么？

这是一个 **加了详细学习注释的 Linux 内核源码仓库**。原始代码来自 [orangepi-xunlong/linux-orangepi](https://github.com/orangepi-xunlong/linux-orangepi)，我们在关键文件上添加了面向新手的逐行中文注释。

### 适合谁？

- 🧑‍💻 想学 Linux 内核但不知从何下手的 **新手**
- 🍊 有 Orange Pi 或其他全志开发板的 **嵌入式爱好者**
- 🔧 想理解编译/启动/设备树等概念的 **开发者**

### 我们做了什么？

整理了一份 **[完整的 Linux 内核学习指南](docs/linux-kernel-learning-guide.md)**，并给以下核心文件添加了中文注释：

```
📄 Makefile                     → 编译系统怎么跑
📄 init/main.c                  → start_kernel() 逐行解析
📁 arch/arm64/configs/          → 所有配置项分段解释
📁 arch/arm64/boot/dts/         → 设备树语法 + 硬件节点解释
```

---

## 🚀 快速开始

### 1️⃣ 环境准备

```bash
# 安装必要的软件包
sudo apt update
sudo apt install -y \
    gcc-aarch64-linux-gnu \     # ARM64 交叉编译器
    build-essential \            # 编译工具 (make, gcc)
    flex bison \                 # 词法/语法分析器
    libssl-dev \                 # SSL 库 (内核签名需要)
    bc                           # 命令行计算器
```

### 2️⃣ 配置内核

```bash
# 使用 Orange Pi 默认配置
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- orangepi_defconfig

# 或者用菜单界面修改配置 (按 / 可搜索)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
```

> 💡 配置文件中所有选项的注释见 [`arch/arm64/configs/orangepi_defconfig`](arch/arm64/configs/orangepi_defconfig)

### 3️⃣ 编译

```bash
# 使用全部 CPU 核心并行编译
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# 编译内核 (推荐用压缩版 Image.gz)
make -j$(nproc) Image.gz

# 编译设备树
make -j$(nproc) dtbs

# 编译内核模块
make -j$(nproc) modules

# 也可以一步到位
make -j$(nproc) Image.gz dtbs modules
```

### 4️⃣ 查看编译产物

```bash
ls -lh arch/arm64/boot/Image*   # 内核镜像
find arch/arm64/boot/dts -name "*.dtb"  # 设备树
ls vmlinux                     # ELF 格式内核 (调试用)
```

| 产物 | 大小 | 说明 |
|------|------|------|
| `arch/arm64/boot/Image` | 23MB | 未压缩内核 (U-Boot 可能加载失败) |
| `arch/arm64/boot/Image.gz` | 9.1MB | **推荐使用** 压缩内核 |
| `vmlinux` | 25MB | ELF 格式，含符号，调试用 |
| `System.map` | 3.9MB | 内核符号地址表 |

---

## 📁 项目结构速览

```
linux-orangepi/
│
├── 📄 README.md              ← 📍 你现在正在看这里
├── 📄 Makefile                ← 🎯 编译入口
├── 📄 .config                 ← ⚡ 实际编译配置
│
├── 📁 docs/
│   └── linux-kernel-learning-guide.md  ← 📖 完整学习指南
│
├── 📁 arch/                   ← 🏗️ CPU 架构代码
│   ├── arm64/                 ← ARM64 (我们的目标)
│   │   ├── Makefile           ← ARM64 编译规则
│   │   ├── Kconfig            ← ARM64 配置菜单
│   │   ├── Kconfig.platforms  ← SoC/厂商选择
│   │   ├── configs/
│   │   │   └── orangepi_defconfig ← ★ 关键文件
│   │   └── boot/dts/allwinner/
│   │       ├── sun50i-h5.dtsi                ← H5 芯片级
│   │       └── sun50i-h5-orangepi-prime.dts  ← ★ 板级 DTS
│   └── arm/                  ← 32-bit ARM (可参考)
│
├── 📁 init/
│   └── main.c                ← ★ start_kernel() 内核入口
│
├── 📁 kernel/                ← ⚙️ 核心子系统
│   ├── sched/                ← 进程调度 (CFS)
│   ├── irq/                  ← 中断处理
│   ├── time/                 ← 定时器
│   ├── fork.c                ← 进程创建
│   └── signal.c              ← 信号处理
│
├── 📁 mm/                    ← 🧠 内存管理
│   ├── page_alloc.c          ← 物理页分配 (伙伴系统)
│   ├── slab.c                ← 小对象分配
│   └── vmalloc.c             ← 虚拟连续内存
│
├── 📁 fs/                    ← 📂 文件系统
│   ├── ext4/                 ← EXT4 (最常用)
│   ├── proc/                 ← /proc 伪文件系统
│   └── sysfs/                ← /sys 设备模型
│
├── 📁 net/                   ← 🌐 网络协议栈
│
├── 📁 drivers/               ← 🔌 设备驱动
│   ├── net/ethernet/stmicro/stmmac/
│   │   └── dwmac-sun8i.c     ← ★ Allwinner 网卡驱动
│   ├── mmc/host/sunxi-mmc.c  ← SD/eMMC 驱动
│   ├── clk/sunxi-ng/         ← Allwinner 时钟驱动
│   └── pinctrl/sunxi/        ← GPIO/引脚控制
│
├── 📁 include/               ← 📋 头文件
│
└── 📁 scripts/               ← 🔧 编译工具
```

---

## 🏷️ 代码注释清单

以下文件都添加了中文学习注释：

| # | 文件 | 注释内容 | 行数 |
|---|------|---------|------|
| 1 | [`Makefile`](Makefile) | 编译目标、常用变量、交叉编译说明 | 1889 |
| 2 | [`init/main.c`](init/main.c) | `start_kernel()` 每个初始化步骤的含义 | 1258 |
| 3 | [`arch/arm64/Makefile`](arch/arm64/Makefile) | `-mgeneral-regs-only`、`-mabi=lp64` 等标志说明 | 190 |
| 4 | [`arch/arm64/Kconfig.platforms`](arch/arm64/Kconfig.platforms) | ARM64 平台选择 + `ARCH_SUNXI` 详解 | 318 |
| 5 | [`arch/arm64/configs/orangepi_defconfig`](arch/arm64/configs/orangepi_defconfig) | **全部配置项分段注释** (通用/CPU/电源/加密/网络/文件系统/调试) | 733 |
| 6 | [`arch/arm64/boot/dts/allwinner/sun50i-h5-orangepi-prime.dts`](arch/arm64/boot/dts/allwinner/sun50i-h5-orangepi-prime.dts) | 设备树语法 + 每个硬件节点含义 | 418 |
| 7 | [`arch/arm64/boot/dts/allwinner/sun50i-h5.dtsi`](arch/arm64/boot/dts/allwinner/sun50i-h5.dtsi) | H5 SoC 特性、H3 vs H5 差异、PSCI 说明 | 378 |

---

## 🖥️ QEMU 测试

### 搭建测试环境

```bash
sudo apt install qemu-system-arm

# 编译 ARM64 busybox 作为根文件系统
cd /tmp
wget https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar xf busybox-1.36.1.tar.bz2
cd busybox-1.36.1
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CONFIG_PREFIX=/tmp/initramfs install
```

### 创建 initramfs

```bash
mkdir -p /tmp/initramfs/{bin,dev,proc,sys,tmp}
cp /tmp/busybox-arm64/bin/busybox /tmp/initramfs/bin/

cat > /tmp/initramfs/init << 'EOF'
#!/bin/busybox sh
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev
/bin/busybox --install -s /bin
echo ""
echo "============================================"
echo "  🍊 Orange Pi Kernel - QEMU Test PASSED!"
echo "============================================"
echo ""
echo "Kernel: $(cat /proc/version)"
echo "CPUs:   $(grep -c processor /proc/cpuinfo) cores"
echo "Memory: $(grep MemTotal /proc/meminfo)"
echo ""
exec /bin/sh
EOF
chmod +x /tmp/initramfs/init

cd /tmp/initramfs && find . | cpio -o --format=newc | gzip -9 > /tmp/initramfs.cpio.gz
```

### 启动 QEMU

```bash
cd /home/gaoyubo/linux-orangepi
qemu-system-aarch64 \
  -machine virt \
  -cpu cortex-a53 \
  -m 256M \
  -kernel arch/arm64/boot/Image \
  -initrd /tmp/initramfs.cpio.gz \
  -append "console=ttyAMA0" \
  -nographic \
  -no-reboot
```

> ⚠️ 内核需要编译了 `CONFIG_SERIAL_AMBA_PL011=y` 才能在 QEMU `virt` 机器上输出控制台。
> 按 `Ctrl + A` 然后按 `X` 可退出 QEMU。

---

## ⚠️ 注意事项

### 1. 使用 Image.gz 而非 Image

部署到 Orange Pi 或 QEMU 时，**建议使用压缩版 `Image.gz`**。未压缩的 `Image`（23MB）可能超出 U-Boot 的加载地址范围，导致启动失败。

```bash
# 推荐
cp arch/arm64/boot/Image.gz /boot/vmlinuz-xxx
ln -sf vmlinuz-xxx /boot/Image

# 不推荐
cp arch/arm64/boot/Image /boot/
```

### 2. 清理 EXTRA_FIRMWARE 配置

`orangepi_defconfig` 中引用了外部固件路径：
```ini
CONFIG_EXTRA_FIRMWARE="regulatory.db ..."
CONFIG_EXTRA_FIRMWARE_DIR="/workspace/megous.com/orangepi-pc/firmware"
```

如果编译时报错找不到固件，需要清空这两项：
```bash
sed -i 's/CONFIG_EXTRA_FIRMWARE=".*"/CONFIG_EXTRA_FIRMWARE=""/' .config
sed -i 's|CONFIG_EXTRA_FIRMWARE_DIR=".*"|CONFIG_EXTRA_FIRMWARE_DIR=""|' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
```

### 3. 为 QEMU 添加 PL011 串口

这颗内核为 Orange Pi H5 优化，默认使用 DesignWare 8250 串口。QEMU `virt` 机器使用 PL011 串口，需要：

```bash
echo "CONFIG_SERIAL_AMBA_PL011=y" >> .config
echo "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y" >> .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image
```

### 4. 禁止 xradio WiFi 驱动

如果编译报 `xradio` 驱动错误 (新 GCC 不兼容)，禁用即可：

```bash
sed -i 's/CONFIG_WLAN_VENDOR_XRADIO=y/# CONFIG_WLAN_VENDOR_XRADIO is not set/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
```

---

## 🧭 学习路线建议

跟随 **[学习指南](docs/linux-kernel-learning-guide.md#第七章学习路线图)** 的四个阶段：

### 阶段一：打基础 (1-2 周)

```
☐ 理解"内核是什么" (学习指南第〇章)
☐ 看懂源码目录结构
☐ 能编译和部署内核
☐ 会使用 dmesg, lsmod, uname 等命令
```

**看什么**: [学习指南 第〇章~第一章](docs/linux-kernel-learning-guide.md#第〇章基础知识速成)

### 阶段二：跟踪启动 (2-4 周)

```
☐ 理解 U-Boot → 内核的交接
☐ 读懂 start_kernel() 的主要步骤
☐ 理解设备树匹配机制
☐ 知道 PID=0 和 PID=1 怎么来的
```

**看什么**: [学习指南 第二章](docs/linux-kernel-learning-guide.md#第二章内核启动流程从头到尾) + `init/main.c`

### 阶段三：深入子系统 (4-8 周)

```
🎯 驱动方向: platform driver, GPIO, 网卡驱动
🎯 网络方向: sk_buff, netfilter, TCP/IP
🎯 文件系统: VFS, ext4 磁盘布局
```

**看什么**: [学习指南 第三章~第五章](docs/linux-kernel-learning-guide.md#第三章编译系统详解)

### 阶段四：动手实战

```
☐ 修改设备树调整引脚功能
☐ 写一个简单的内核模块
☐ 移植一个驱动
☐ 向社区提交补丁
```

---

## 📚 相关资源

### 在线工具

| 工具 | 链接 | 用途 |
|------|------|------|
| Elixir 内核源码浏览器 | https://elixir.bootlin.com/linux/latest/source | 在线跳转定义/引用 |
| Device Tree 规范 | https://devicetree-specification.readthedocs.io/ | 设备树官方文档 |
| linux-sunxi Wiki | https://linux-sunxi.org/ | 全志芯片开源社区 |
| ARM 架构手册 | https://developer.arm.com/documentation | ARMv8-A 参考 |

### 推荐书籍

| 书名 | 难度 | 适合 |
|------|------|------|
| 《Linux 内核设计与实现》Robert Love | ⭐⭐ | 入门必读 |
| 《Linux 设备驱动程序》LDD3 | ⭐⭐⭐ | 驱动开发 |
| 《深入理解 Linux 内核》 | ⭐⭐⭐⭐ | 进阶深入 |

### 社区

- [linux-sunxi 邮件列表](https://groups.google.com/g/linux-sunxi)
- [Orange Pi 论坛](https://forum.orangepi.org/)
- [Linux Kernel Newbies](https://kernelnewbies.org/)
- [LKML (Linux Kernel Mailing List)](https://lkml.org/)

---

## 📜 许可证

本项目基于 [GPL v2](COPYING) 许可证发布。源码来自 [orangepi-xunlong/linux-orangepi](https://github.com/orangepi-xunlong/linux-orangepi)，注释和学习文档使用相同的许可证。

---

<p align="center">
<strong>🍊 Happy Hacking! 🐧</strong><br>
<sub>内核版本 5.4.65 · 目标板 Orange Pi Prime · Allwinner H5 (Cortex-A53)</sub>
</p>
