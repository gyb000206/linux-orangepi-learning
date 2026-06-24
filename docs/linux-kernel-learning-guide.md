# 🐧 Linux 内核零基础学习指南

> **基于 Orange Pi Prime (Allwinner H5, arm64) 内核 5.4.65**
>
> 写给我自己的内核学习笔记 — 从零开始理解 Linux 内核

---

## 📌 写在最前面

### 这是什么？

Linux 内核是操作系统的核心。你的 Orange Pi 能跑起来，全靠它管理 CPU、内存、硬盘、网络等所有硬件。这份指南会带你：

1. **看懂**内核源码是怎么组织的
2. **理解**内核是怎么启动的
3. **学会**怎么编译和部署内核
4. **掌握**调试和修改内核的基本方法

### 学习心态

> 内核代码有 2000 万行，没有人能全部看懂。关键是掌握"怎么找到你想看的那部分"。

- 不要试图一次看懂所有代码
- 从你感兴趣的部分开始（比如：Orange Pi 的网卡驱动）
- 善用 `grep`、`cscope`、在线代码浏览器
- 多动手：改一个小参数，编译，跑起来，看效果

---

## 第〇章：基础知识速成

### Q1: 内核是什么？

```
┌──────────────────────────────────┐
│         你的程序 (app)            │  ← 用户空间
├──────────────────────────────────┤
│        系统调用接口               │  ← 用户↔内核的分界线
├──────────────────────────────────┤
│    ┌──────────────────────────┐  │
│    │     Linux 内核            │  │  ← 内核空间
│    │  - 进程管理 (谁先跑)      │  │
│    │  - 内存管理 (内存怎么分)   │  │
│    │  - 文件系统 (文件存哪里)   │  │
│    │  - 网络协议栈 (网络怎么通) │  │
│    │  - 设备驱动 (硬件怎么用)   │  │
│    └──────────────────────────┘  │
├──────────────────────────────────┤
│         硬件 (CPU/内存/硬盘...)   │  ← 物理世界
└──────────────────────────────────┘
```

**一句话概括**：内核就是硬件的"管家"，应用程序想用硬件必须通过内核。

### Q2: 交叉编译是什么？

你用来写代码的电脑是 **x86_64 架构**（Intel/AMD CPU），Orange Pi 是 **ARM64 架构**。两种 CPU 的指令集完全不同！

所以你需要一个"翻译官"——**交叉编译器** `aarch64-linux-gnu-gcc`：
- 在你 x86 电脑上运行
- 但生成的程序是 ARM64 指令
- 然后通过网络/串口/SD卡传给 Orange Pi 运行

### Q3: 设备树 (Device Tree) 是什么？

传统 PC 有 BIOS/UEFI，硬件信息由固件告知操作系统。但 ARM 嵌入式设备没有这些！

**设备树 (.dts/.dtb)** 就是 ARM 世界的"硬件说明书"：
```dts
// 告诉内核：我有一盏绿灯，接在 GPIO PL10 引脚上
pwr {
    label = "orangepi:green:pwr";     // 灯的名字
    gpios = <&r_pio 0 10 GPIO_ACTIVE_HIGH>;  // 接到 PL10
    default-state = "on";             // 默认亮着
};
```

内核启动时读取设备树，就知道有哪些硬件、在哪里、怎么操作。

### Q4: U-Boot 是什么？

U-Boot 是启动加载器（bootloader），它在内核之前运行：
1. 芯片上电 → 运行片内 ROM 代码
2. ROM 加载 U-Boot（从 SD 卡/eMMC/SPI Flash）
3. U-Boot 初始化内存、读取内核和设备树
4. U-Boot 跳转到内核入口，交出控制权

**U-Boot → 内核的交接**：
```bash
# U-Boot 做的事情（boot.cmd 脚本）:
load mmc 0:1 ${kernel_addr} /boot/Image      # 把内核读到内存
load mmc 0:1 ${fdt_addr} /boot/dtb/xxx.dtb    # 把设备树读到内存
booti ${kernel_addr} ${ramdisk_addr} ${fdt_addr}  # 启动!
```

---

## 第一章：内核源码目录结构（详解版）

```
linux-orangepi/                        ← 内核源码根目录
│
├── 📄 Makefile                        ← 🎯 编译入口
│   │  定义: VERSION=5 PATCHLEVEL=4 SUBLEVEL=65
│   │  用法: make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image
│   │
├── 📄 Kconfig                         ← 🎛️ 配置菜单定义
│   │  make menuconfig 看到的菜单由此文件及子目录的 Kconfig 构成
│   │
├── 📄 .config                         ← ⚡ 你的实际编译配置
│   │  由 make *_defconfig 生成，编译时实际生效
│   │
├── 📁 arch/                           ← 🏗️  CPU架构代码
│   ├── arm64/                         ← ARM64 (我们用的)
│   │   ├── Makefile                   ← arm64 专用编译规则
│   │   ├── Kconfig                    ← arm64 架构配置选项
│   │   ├── Kconfig.platforms          ← 选择 SoC 厂商 (全志/博通/高通...)
│   │   ├── configs/                   ← 默认配置文件
│   │   │   └── orangepi_defconfig     ← ★ 我们的配置!
│   │   ├── boot/
│   │   │   ├── dts/allwinner/         ← 设备树源文件
│   │   │   │   ├── sun50i-h5.dtsi               ← H5 SoC 级
│   │   │   │   ├── sunxi-h3-h5.dtsi             ← H3/H5 共用
│   │   │   │   └── sun50i-h5-orangepi-prime.dts ← 板级 ★
│   │   │   └── Image                  ← 编译产物: 内核镜像
│   │   ├── kernel/                    ← 汇编启动代码、信号处理等
│   │   │   └── head.S                 ← ★ 内核第一行代码 (汇编入口)
│   │   └── mm/                        ← arm64 内存管理 (页表、TLB)
│   │
│   └── arm/                           ← ARM32 (老版本 Orange Pi 用)
│
├── 📁 init/                           ← 🚀 内核启动初始化
│   ├── main.c                         ← ★ start_kernel() 函数在这里!
│   │   │  这是 Linux 内核的 C 语言入口点
│   │   │  内核启动流程: head.S → start_kernel() → rest_init()
│   │   └── version.c                  ← 打印 Linux 版本信息
│   │
├── 📁 kernel/                         ← ⚙️ 核心子系统
│   ├── sched/                         ← 进程调度器 (CFS)
│   │   └── fair.c                     ← 完全公平调度算法
│   ├── irq/                           ← 中断处理
│   ├── time/                          ← 定时器
│   ├── fork.c                         ← 创建新进程 (fork)
│   ├── signal.c                       ← 信号处理
│   └── printk.c                       ← 内核日志 (dmesg 的来源)
│
├── 📁 mm/                             ← 🧠 内存管理
│   ├── page_alloc.c                   ← 伙伴系统 (分配物理页)
│   ├── slab.c                         ← slab 分配器 (分配小对象)
│   ├── vmalloc.c                      ← 虚拟连续内存
│   └── kmalloc.c                      ← 内核内存分配 (类似 malloc)
│
├── 📁 fs/                             ← 📂 文件系统
│   ├── ext4/                          ← EXT4 文件系统 (Linux 最常用)
│   ├── vfat/                          ← FAT32/exFAT (U盘格式)
│   ├── proc/                          ← /proc 伪文件系统
│   └── sysfs/                         ← /sys 伪文件系统 (设备模型)
│
├── 📁 net/                            ← 🌐 网络协议栈
│   ├── ipv4/                          ← TCP/IPv4
│   ├── core/                          ← 套接字核心
│   └── netfilter/                     ← 防火墙 (iptables/nftables)
│
├── 📁 drivers/                        ← 🔌 设备驱动 (最大目录!)
│   ├── net/ethernet/stmicro/stmmac/   ← 千兆网卡驱动框架
│   │   └── dwmac-sun8i.c             ← ★ Allwinner H3/H5/H6 网卡
│   ├── mmc/host/
│   │   └── sunxi-mmc.c               ← ★ Allwinner SD/eMMC 驱动
│   ├── clk/sunxi-ng/                  ← Allwinner 时钟驱动
│   │   └── ccu-sun50i-h5.c           ← H5 时钟树
│   ├── pinctrl/sunxi/                 ← GPIO/引脚控制
│   ├── usb/                           ← USB 驱动
│   ├── gpu/drm/sun4i/                 ← Allwinner 显示驱动
│   ├── watchdog/
│   │   └── sunxi_wdt.c               ← 看门狗驱动
│   └── base/                          ← 驱动模型基础设施
│       ├── driver.c                   ← 总线-设备-驱动模型
│       └── platform.c                 ← platform 设备/驱动
│
├── 📁 include/                        ← 📋 头文件 (API 定义)
│   └── linux/                         ← 内核核心头文件
│       ├── list.h                     ← 链表 (内核最常用的数据结构!)
│       ├── printk.h                   ← printk() 内核日志
│       ├── module.h                   ← 模块相关宏
│       └── of.h                       ← 设备树解析 API (OF=Open Firmware)
│
├── 📁 scripts/                        ← 🔧 编译辅助
│   ├── kconfig/                       ← 配置系统解析器
│   └── Makefile.lib                   ← 通用编译规则
│
├── 📁 Documentation/                  ← 📚 内核文档
│   ├── arm64/booting.rst              ← arm64 启动规范
│   ├── devicetree/                    ← 设备树规范
│   └── arm/sunxi.rst                  ← Allwinner 平台说明
│
├── 📁 tools/                          ← 🛠 用户空间工具
│   └── perf/                          ← 性能分析工具
│
└── 📄 COPYING                         ← GPL v2 许可证
```

---

## 第二章：内核启动流程（从头到尾）

### 2.1 完整的启动链路

```
芯片上电
  ↓
片内 Boot ROM (厂家固化，不可修改)
  ↓ 加载 SPL (Secondary Program Loader)
U-Boot SPL (初始化 DRAM)
  ↓ 加载 U-Boot
U-Boot (完整引导程序)
  │
  ├─ 读取 /boot/boot.scr (启动脚本)
  ├─ 加载设备树到内存 (fdt_addr)
  ├─ 加载内核 Image 到内存 (kernel_addr)
  ├─ 加载 initrd 到内存 (ramdisk_addr)
  └─ booti 跳转到内核入口
      ↓
━━━━━━━━━━━━━━ 内核阶段开始 ━━━━━━━━━━━━━
      ↓
arch/arm64/kernel/head.S          ← 汇编入口 (第一行内核代码)
  ├─ 设置页表 (早期内存映射)
  ├─ 启用 MMU (虚拟内存)
  └─ 跳转到 start_kernel()
      ↓
init/main.c: start_kernel()       ← C 语言入口
  ├─ setup_arch()                 ← 解析设备树，初始化架构相关
  ├─ mm_init()                    ← 内存管理初始化
  ├─ sched_init()                 ← 调度器初始化
  ├─ rest_init()                  ← 创建第一个进程
  │   ├─ kernel_init()            ← PID=1, 加载 init 程序
  │   └─ cpu_idle()               ← PID=0, CPU 空闲时运行的 idle 进程
  │
kernel_init() → 挂载根文件系统 → 执行 /sbin/init
  ↓
用户空间启动 (systemd / sysvinit / busybox)
```

### 2.2 start_kernel() 逐行解读

```c
// 📍 位置: init/main.c 第 576 行
// 这是内核 C 语言的入口！head.S 做完汇编级初始化后调用它

asmlinkage __visible void __init start_kernel(void)
{
    char *command_line;
    char *after_dashes;

    // ① 进程0 (idle进程) 的栈溢出检测标记
    set_task_stack_end_magic(&init_task);
    // init_task 是静态定义的 "进程0", 它是所有进程的祖先

    // ② 设置当前 CPU ID
    smp_setup_processor_id();
    // 多核系统中标识 "我是哪个CPU核心"

    // ③ 调试对象早期初始化
    debug_objects_early_init();

    // ④ cgroup(容器资源控制组) 早期初始化
    cgroup_init_early();
    // Docker 的资源隔离依赖 cgroup!

    // ⑤ ★ 关中断！
    local_irq_disable();
    // 初始化阶段必须关中断，防止不确定的中断扰乱初始化顺序
    early_boot_irqs_disabled = true;

    // ⑥ 启动 CPU 初始化 (设置当前 CPU 状态)
    boot_cpu_init();

    // ⑦ ★ 打印 Linux 版本信息 (你看到的 dmesg 第一行!)
    pr_notice("%s", linux_banner);
    // 输出类似: "Linux version 5.4.65 (...) (aarch64-linux-gnu-gcc ...)"

    // ⑧ 安全框架早期初始化 (SELinux/AppArmor等)
    early_security_init();

    // ⑨ ★★ setup_arch() - 架构相关初始化 (非常重要!)
    setup_arch(&command_line);
    // arm64 的 setup_arch() 会:
    //   1. 解析 U-Boot 传来的设备树 (DTB)
    //   2. 初始化页表、设置内存区域
    //   3. 解析内核命令行参数 (console=, root=, ...)
    //   4. 调用 setup_machine_fdt() 根据 compatible 字符串匹配板卡

    // ⑩ 处理内核命令行
    setup_command_line(command_line);

    // ⑪ 设置 CPU 数量
    setup_nr_cpu_ids();

    // ⑫ 为每个 CPU 分配 per-CPU 数据区域
    setup_per_cpu_areas();
    // 每个CPU都有独立的数据，避免加锁

    // ⑬ SMP 启动准备工作
    smp_prepare_boot_cpu();

    // ⑭ ★ 内存管理初始化
    build_all_zonelists(NULL);     // 构建内存区域列表
    page_alloc_init();             // 页分配器初始化

    // ⑮ 打印完整的命令行 (调试用)
    pr_notice("Kernel command line: %s\n", boot_command_line);

    // ⑯ 解析 early_param 参数 (如 earlyprintk)
    parse_early_param();

    // ⑰ 基本的异常处理
    trap_init();

    // ⑱ ★★ mm_init() - 内存管理子系统初始化
    mm_init();
    // 包括: 伙伴系统、slab分配器、vmalloc、kmem_cache等

    // ⑲ ★ sched_init() - 调度器初始化
    sched_init();
    // 初始化 CFS (完全公平调度器), 初始化运行队列

    // ⑳ 禁止抢占 (初始化完成前不能调度)
    preempt_disable();

    // ㉑ RCU 初始化 (Read-Copy-Update, 无锁同步机制)
    rcu_init();

    // ㉒ ★ 中断初始化
    early_irq_init();             // 早期 IRQ 框架
    init_IRQ();                   // 架构相关中断 (GIC 中断控制器)
    // Allwinner H5 使用 ARM GIC-400 中断控制器

    // ㉓ 定时器初始化
    tick_init();                  // 时钟节拍
    init_timers();                // 内核定时器
    hrtimers_init();              // 高精度定时器

    // ㉔ 时间子系统
    timekeeping_init();           // 时间记录
    time_init();                  // 时钟源 (arch timer)

    // ㉕ 控制台初始化 (console_initcall)
    console_init();
    // ★ 此后 printk 的信息才真正显示到串口/屏幕!

    // ... 更多初始化 ...

    // ㉖ ★ 最后: rest_init() 创建 init 进程
    arch_call_rest_init();
}

// rest_init() 做了关键的两件事:
static void noinline rest_init(void)
{
    // 创建内核线程 kernel_init (PID=1)
    pid = kernel_thread(kernel_init, NULL, CLONE_FS);
    // PID=1 会:
    //   1. 挂载根文件系统
    //   2. 执行 /sbin/init
    //   3. 如果没有 init, 尝试 /bin/sh, /bin/bash...

    // 让当前线程成为 idle 进程 (PID=0)
    cpu_startup_entry(CPUHP_ONLINE);
    // idle 进程在没有任务可运行时占着 CPU
}
```

### 2.3 setup_arch() 设备树匹配过程

```c
// arch/arm64/kernel/setup.c
void __init setup_arch(char **cmdline_p)
{
    // ① 调用 setup_machine_fdt()
    //    读取 U-Boot 传来的设备树指针 (x0 寄存器 = DTB 地址)
    setup_machine_fdt(__fdt_pointer);

    // ② setup_machine_fdt 内部:
    //    从 DTB 根节点读取 "compatible" 属性
    //    值: "xunlong,orangepi-prime", "allwinner,sun50i-h5"
    //
    //    遍历内核中所有注册的平台:
    //    DT_MACHINE_START(SUN50I_H5, "Allwinner sun50i H5")
    //      .dt_compat = sun50i_h5_dt_compat,
    //      // compatible = "allwinner,sun50i-h5"
    //    MACHINE_END
    //
    //    ★ 匹配成功! 用这个 machine_desc 初始化

    // ③ 初始化内存区域
    early_init_fdt_scan_reserved_mem();  // 保留内存 (如 CMA)
    arm64_memblock_init();               // 物理内存块初始化

    // ④ 初始化页表
    paging_init();
    // 建立虚拟地址到物理地址的映射

    // ⑤ 解析命令行
    // 从 DTB 的 /chosen/bootargs 或 U-Boot 传来的 bootargs 读取
}
```

---

## 第三章：编译系统详解

### 3.1 Makefile 工作原理

```makefile
# 📄 顶层 Makefile 关键片段

# --- 内核版本号 ---
VERSION = 5          # 主版本
PATCHLEVEL = 4       # 次版本
SUBLEVEL = 65        # 补丁版本
# → 最终版本: 5.4.65

# --- 输出美化 ---
# 正常: make        → 简洁输出 "  CC    fs/ext4/file.o"
# 详细: make V=1    → 显示完整 gcc 命令行
# 安静: make -s     → 只显示错误

# --- 递归构建 ---
# 顶层 Makefile 会进入每个子目录，执行该目录的 Makefile
# 最终把所有 built-in.a 链接成 vmlinux

# --- 编译目标 ---
# Image:      未压缩内核 (objcopy vmlinux → Image)
# Image.gz:   gzip 压缩内核
# vmlinux:    未裁剪的 ELF 文件
# modules:    编译所有配置为 =m 的模块
# dtbs:       编译所有设备树
```

### 3.2 arm64 专用编译标志

```makefile
# 📄 arch/arm64/Makefile

# ★ -mgeneral-regs-only
# 禁止 GCC 使用浮点/NEON 寄存器
# 原因: 内核态不保存浮点上下文，用了会导致数据损坏
KBUILD_CFLAGS += -mgeneral-regs-only

# ★ -mabi=lp64
# LP64 数据模型: Long=64bit, Pointer=64bit
# Win64 用 LLP64 (Long=32bit, Long Long=64bit)
# Linux 统一用 LP64
KBUILD_CFLAGS += $(call cc-option,-mabi=lp64)

# ★ -fno-asynchronous-unwind-tables
# 不生成异步展开表 (用于 C++ 异常)
# 内核不用 C++ 异常，省空间
KBUILD_CFLAGS += -fno-asynchronous-unwind-tables
```

### 3.3 Kconfig 配置系统

```
顶层 Kconfig
├── source "arch/arm64/Kconfig"
│   ├── source "arch/arm64/Kconfig.platforms"  ← 选平台
│   │   └── config ARCH_SUNXI                   ← 我们的选择
│   └── ...
├── source "kernel/Kconfig.sched"
├── source "mm/Kconfig"
├── source "drivers/net/Kconfig"
│   └── source "drivers/net/ethernet/stmicro/stmmac/Kconfig"
│       └── config DWMAC_SUN8I                  ← 我们的网卡
└── ...

当你 make menuconfig:
  1. 读取所有 Kconfig 构建配置菜单树
  2. 每个选项有 type (bool/tristate/int/string), default, depends, select
  3. 你的选择写入 .config

当你 make orangepi_defconfig:
  1. 复制 arch/arm64/configs/orangepi_defconfig → .config
  2. 运行 make olddefconfig 补充缺失的默认值
```

### 3.4 编译过程（从 .config 到 Image）

```
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image

1️⃣ 配置阶段
   scripts/kconfig/conf --olddefconfig Kconfig
   → 生成 include/generated/autoconf.h (C 语言宏)
   → 更新 include/config/ (每个配置项一个头文件)

2️⃣ 编译阶段 (并行 -jN)
   gcc 编译每个 .c → .o
   每个子目录生成 built-in.a (包含该目录所有 =y 的 .o)
   
   例如 drivers/net/ethernet/stmicro/stmmac/:
     dwmac-sun8i.o  →  drivers/net/../stmmac/built-in.a
     dwmac-sunxi.o  ↗

3️⃣ 链接阶段
   LD vmlinux
   → 把所有 built-in.a 链接成一个大的 ELF 文件
   → vmlinux (~25MB)

4️⃣ 裁剪阶段
   OBJCOPY arch/arm64/boot/Image
   → 去掉 ELF 头、符号表、调试信息
   → Image (~23MB) 纯二进制，U-Boot 可以直接加载

5️⃣ 压缩阶段 (如果 make Image.gz)
   GZIP arch/arm64/boot/Image.gz
   → gzip 压缩 Image
   → Image.gz (~9MB)
```

---

## 第四章：设备树详解

### 4.1 设备树文件层级

```
sun50i-h5-orangepi-prime.dts    ← 板级 (你的 Orange Pi Prime)
│   #include "sun50i-h5.dtsi"
│
├── sun50i-h5.dtsi               ← SoC 级 (H5 芯片)
│   #include <arm/sunxi-h3-h5.dtsi>
│   │
│   └── sunxi-h3-h5.dtsi         ← 平台级 (H3/H5 共用)
│       #include <dt-bindings/...>
│
└── 最终编译结果:
    sun50i-h5-orangepi-prime.dtb  (设备树二进制)
```

### 4.2 设备树语法速查

```dts
// ① 节点 (Node): 用标签描述一个硬件组件
label: node-name@unit-address {
    property-name = <值>;
};

// ② 兼容性 (compatible): 驱动匹配的关键!
compatible = "厂商,型号", "更通用的型号";
// 例: compatible = "xunlong,orangepi-prime", "allwinner,sun50i-h5";
// 内核驱动中:
//   static const struct of_device_id xxx_match[] = {
//       { .compatible = "allwinner,sun50i-h5" },  ← 匹配!
//   };

// ③ 状态 (status): 启用/禁用设备
status = "okay";     // 启用
status = "disabled"; // 禁用
// 通常 SoC 级 dtsi 中默认 disabled, 板级 dts 中覆盖为 okay

// ④ 引用和覆盖 (&)
&uart0 {              // 引用 sunxi-h3-h5.dtsi 中的 uart0 节点
    status = "okay";  // 覆盖 status 属性
    pinctrl-0 = <&uart0_pa_pins>;  // 添加引脚配置
};

// ⑤ 标签 (Label): 给节点起别名, 方便引用
reg_vcc3v3: vcc3v3 {  // 标签 : 节点名
    compatible = "regulator-fixed";
};
// 其他地方引用: cpu-supply = <&reg_vcc3v3>;

// ⑥ 中断号
interrupts = <GIC_SPI 72 IRQ_TYPE_LEVEL_HIGH>;
// GIC_SPI = 共享外设中断, 72 = 硬件中断号

// ⑦ GPIO 引用
gpios = <&pio 5 6 GPIO_ACTIVE_LOW>;
// &pio = 端口控制器, 5 = 端口F, 6 = 引脚6, 低电平有效
// 等效于: PF6
```

### 4.3 Orange Pi Prime 设备树关键节点

```dts
/ {
    // ═══════════════════════════════════════
    // 🏷️  板卡标识 (内核用这个匹配板子)
    // ═══════════════════════════════════════
    model = "Xunlong Orange Pi Prime";
    compatible = "xunlong,orangepi-prime", "allwinner,sun50i-h5";

    // ═══════════════════════════════════════
    // 🔌 3.3V 固定电压 (很多外设共用这个供电)
    // ═══════════════════════════════════════
    reg_vcc3v3: vcc3v3 {
        compatible = "regulator-fixed";
        regulator-name = "vcc3v3";
        regulator-min-microvolt = <3300000>;   // 3.3V
        regulator-max-microvolt = <3300000>;
    };

    // ═══════════════════════════════════════
    // 📛 别名: 给硬件接口起逻辑名
    //    eth0 → 有线网卡, wlan0 → WiFi
    // ═══════════════════════════════════════
    aliases {
        ethernet0 = &emac;      // eth0 → 千兆有线
        serial0 = &uart0;       // ttyS0 → 调试串口
        ethernet1 = &rtl8723cs; // wlan0 → RTL8723CS WiFi
    };

    // ═══════════════════════════════════════
    // 📟 内核启动参数
    // ═══════════════════════════════════════
    chosen {
        stdout-path = "serial0:115200n8";
        // 启动日志从 UART0 输出, 波特率115200
    };

    // ═══════════════════════════════════════
    // 💡 LED 灯
    // ═══════════════════════════════════════
    leds {
        compatible = "gpio-leds";   // 用 GPIO 控制的 LED

        pwr {   // 绿色电源灯 (PL10)
            label = "orangepi:green:pwr";
            gpios = <&r_pio 0 10 GPIO_ACTIVE_HIGH>;
            // &r_pio = R_PIO 域 (独立于主 PIO, 用于低功耗场景)
            // 0 = 端口 L (PL)
            // 10 = 引脚 10
            default-state = "on";
        };

        status {  // 红色状态灯 (PA20)
            label = "orangepi:red:status";
            gpios = <&pio 0 20 GPIO_ACTIVE_HIGH>;
            // &pio = 主 PIO 域
            // 0 = 端口 A (PA)
            // 20 = 引脚 20
            default-state = "off";
        };
    };
};

// ═════════════════════════════════════
// 以下是通过 & 引用 SoC 外设并启用
// ═════════════════════════════════════

// 🌐 千兆以太网 (EMAC)
&emac {
    pinctrl-0 = <&emac_rgmii_pins>;     // 引脚: RGMII 模式
    phy-supply = <&reg_gmac_3v3>;       // PHY 芯片供电
    phy-handle = <&ext_rgmii_phy>;      // PHY 在 MDIO 地址 1
    phy-mode = "rgmii";                 // 接口模式
    status = "okay";
};

// 📡 WiFi (SDIO 接口, 接在 MMC1)
&mmc1 {
    vmmc-supply = <&reg_vcc3v3>;
    mmc-pwrseq = <&wifi_pwrseq>;        // WiFi 上电时序
    bus-width = <4>;                    // 4 位数据线
    non-removable;                      // 模块焊接在板上
    status = "okay";
};

// 💾 SD 卡槽 (MMC0)
&mmc0 {
    vmmc-supply = <&reg_vcc3v3>;
    bus-width = <4>;
    cd-gpios = <&pio 5 6 GPIO_ACTIVE_LOW>;  // PF6 检测卡插入
    status = "okay";
};

// 🔌 USB 2.0 主机接口
&ehci0 { status = "okay"; };  // 上层 USB-A 口
&ehci1 { status = "okay"; };  // 上层 USB-A 口
&ehci2 { status = "okay"; };  // 下层 USB-A 口
&ehci3 { status = "okay"; };  // 下层 USB-A 口
&ohci0 { status = "okay"; };  // USB 1.1 兼容

// 🖥️  HDMI 显示
&hdmi  { status = "okay"; };
&de    { status = "okay"; };    // Display Engine 2.0

// 📟 调试串口
&uart0 {
    pinctrl-0 = <&uart0_pa_pins>;  // PA4(TX) PA5(RX)
    status = "okay";
};
```

---

## 第五章：Allwinner H5 平台知识

### 5.1 SoC 架构

```
┌──────────────────────────────────────────────┐
│              Allwinner H5 (sun50i-h5)         │
│                                               │
│  ┌─────────────────────────────────────┐     │
│  │  4 × ARM Cortex-A53 @ 1.3GHz        │     │
│  │  ARMv8-A, 64-bit, L1=32KB L2=512KB  │     │
│  └─────────────────────────────────────┘     │
│                                               │
│  GIC-400 中断控制器                           │
│  ARM Arch Timer (通用定时器)                  │
│                                               │
│  ┌─────────────┐  ┌──────────────────────┐   │
│  │ Mali-450 MP4│  │ Display Engine 2.0   │   │
│  │ GPU         │  │ HDMI 1.4 + CVBS      │   │
│  └─────────────┘  └──────────────────────┘   │
│                                               │
│  ┌─────────────┐  ┌──────────────────────┐   │
│  │ DDR3/DDR3L  │  │ 10/100/1000M EMAC    │   │
│  │ Controller  │  │ + RGMII PHY          │   │
│  └─────────────┘  └──────────────────────┘   │
│                                               │
│  ┌─────────────┐  ┌──────────────────────┐   │
│  │ SDIO 3.0 ×1 │  │ USB 2.0 Host ×4      │   │
│  │ eMMC 5.0 ×1 │  │ USB OTG ×1           │   │
│  └─────────────┘  └──────────────────────┘   │
│                                               │
│  UART×6, I2C×4, SPI×2, IR, CSI, I2S, SPDIF  │
└──────────────────────────────────────────────┘
```

### 5.2 内存地址映射

```
H5 物理地址空间:
0x00000000 - 0x3FFFFFFF  ← DRAM (1GB for Orange Pi Prime)
0x40000000 - 0xBFFFFFFF  ← 未使用 (可映射更多 DRAM)
0x01C00000 - 0x01FFFFFF  ← 外设寄存器基址
   0x01C20000 + 0x0000   ← PIO (GPIO) 寄存器
   0x01C20000 + 0x0800   ← R_PIO (低功耗 GPIO)
   0x01C28000            ← UART0
   0x01C30000            ← EMAC (以太网)
   0x01C0F000            ← MMC0 (SD 卡)
   0x01C10000            ← MMC1 (WiFi)
   0x01C20000            ← CCU (时钟控制单元)
```

### 5.3 GPIO 计算公式

```
Allwinner GPIO 编号:
  物理位置: PA0, PA1, ..., PB0, ..., PL0, ...
  计算公式: 端口字母序号 × 32 + 引脚号

  A=0, B=1, C=2, D=3, E=4, F=5, G=6, H=7
  I=8, J=9, K=10, L=11

  PA0 = 0×32 + 0 = 0      PA20 = 0×32 + 20 = 20
  PC14 = 2×32 + 14 = 78   PF6 = 5×32 + 6 = 166
  PL10 = 11×32 + 10 = 362

在 /sys/class/gpio/ 中:
  echo 166 > export      # 导出 PF6
```

### 5.4 关键驱动文件位置

| 功能 | 驱动源文件 | 说明 |
|------|-----------|------|
| 时钟控制 | `drivers/clk/sunxi-ng/ccu-sun50i-h5.c` | H5 时钟树配置 |
| GPIO/引脚复用 | `drivers/pinctrl/sunxi/pinctrl-sun50i-h5.c` | 引脚功能配置 |
| 千兆网卡 | `drivers/net/ethernet/stmicro/stmmac/dwmac-sun8i.c` | EMAC + RGMII PHY |
| SD/eMMC | `drivers/mmc/host/sunxi-mmc.c` | MMC 控制器 |
| USB Host (EHCI) | `drivers/usb/host/ehci-sunxi.c` | USB 2.0 |
| USB OTG | `drivers/usb/musb/sunxi.c` | USB OTG (可做主或从) |
| 显示 (DRM) | `drivers/gpu/drm/sun4i/` | HDMI/显示引擎 |
| 看门狗 | `drivers/watchdog/sunxi_wdt.c` | 系统死机自动复位 |
| 红外 | `drivers/media/rc/sunxi-cir.c` | 红外遥控接收 |
| 音频 | `sound/soc/sunxi/` | 音频编解码 |

---

## 第六章：实用操作手册

### 6.1 编译命令速查

```bash
# ==========================================
# 0. 环境准备 (只需一次)
# ==========================================
sudo apt update
sudo apt install -y gcc-aarch64-linux-gnu build-essential \
    flex bison libssl-dev bc u-boot-tools

# ==========================================
# 1. 配置内核
# ==========================================
# 方法A: 使用默认配置
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- orangepi_defconfig

# 方法B: 图形化修改配置
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
# 搜索功能: 按 / 输入关键词, 会显示该选项的位置和依赖关系

# 方法C: 基于当前配置调整
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

# ==========================================
# 2. 编译
# ==========================================
# 编译内核镜像 (推荐用压缩版)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image.gz

# 编译设备树
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) dtbs

# 编译模块
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) modules

# 一键全部编译
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image.gz modules dtbs

# ==========================================
# 3. 安装模块到临时目录
# ==========================================
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    INSTALL_MOD_PATH=/tmp/kernel-modules modules_install

# ==========================================
# 4. 部署到 Orange Pi
# ==========================================
# 假设设备 IP 是 192.168.31.125
sshpass -p "orangepi" scp arch/arm64/boot/Image.gz \
    root@192.168.31.125:/boot/

sshpass -p "orangepi" scp arch/arm64/boot/dts/allwinner/sun50i-h5-orangepi-prime.dtb \
    root@192.168.31.125:/boot/dtb/allwinner/

sshpass -p "orangepi" scp -r /tmp/kernel-modules/lib/modules/* \
    root@192.168.31.125:/lib/modules/

# 更新启动链接
sshpass -p "orangepi" ssh root@192.168.31.125 \
    "ln -sf Image.gz /boot/Image && reboot"

# ==========================================
# 5. 清理
# ==========================================
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- clean     # 清理编译产物
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- mrproper  # 清理所有(含.config)
```

### 6.2 调试命令速查

```bash
# === 内核日志 ===
dmesg                          # 查看全部内核日志
dmesg | tail -50               # 查看最近 50 行
dmesg | grep -i error          # 搜索错误
dmesg -w                       # 实时跟踪 (类似 tail -f)

# === 内核版本和配置 ===
uname -a                       # 查看运行的内核版本
cat /proc/version              # 更详细的内核版本
zcat /proc/config.gz           # 查看运行内核的配置
cat /proc/cmdline              # 查看内核启动参数

# === 设备树 ===
ls /proc/device-tree/          # 查看内核解析的设备树
cat /proc/device-tree/model    # 查看板卡型号

# === 模块操作 ===
lsmod                          # 列出已加载的模块
modinfo <module_name>          # 模块详细信息
modprobe <module_name>         # 加载模块+依赖
rmmod <module_name>            # 卸载模块

# === GPIO 调试 ===
cat /sys/kernel/debug/gpio     # 查看 GPIO 状态
echo 166 > /sys/class/gpio/export    # 导出 GPIO
echo out > /sys/class/gpio/gpio166/direction  # 设为输出
echo 1 > /sys/class/gpio/gpio166/value       # 输出高电平

# === 中断调试 ===
cat /proc/interrupts           # 查看中断统计

# === 内存信息 ===
cat /proc/meminfo              # 内存使用详情
cat /proc/slabinfo             # slab 内存统计

# === 性能分析 ===
perf top                       # 实时性能分析
perf record -a -g sleep 10     # 记录 10 秒系统活动
perf report                    # 查看分析报告
```

### 6.3 源码搜索技巧

```bash
# === 找符号定义 ===
# 方法1: cscope (推荐!)
cscope -R -k -q                # 生成索引
cscope -d                      # 交互式搜索

# 方法2: ctags
ctags -R                       # 生成标签文件
vim -t start_kernel            # 跳转到函数定义

# 方法3: git grep (最快!)
git grep "start_kernel"        # 全文搜索
git grep -n "config ARCH_SUNXI" -- "*Kconfig*"  # 搜 Kconfig

# === 找驱动 ===
# 通过 compatible 字符串找驱动:
git grep "allwinner,sun50i-h5-emac"
# 输出: drivers/net/ethernet/stmicro/stmmac/dwmac-sun8i.c
#        → 这就是 H5 的网卡驱动!

# === 找配置项定义 ===
git grep "config DWMAC_SUN8I" -- "*Kconfig*"
# 输出: drivers/net/.../stmmac/Kconfig: 这里是配置菜单定义

# === 追踪调用链 ===
# 找谁调用了这个函数:
git grep "setup_arch("
# 找这个函数调用了谁:
# 读函数体, 或用 cscope

# === 在线工具 ===
# https://elixir.bootlin.com/linux/latest/source
# 可以点击跳转到函数定义、引用，比本地 grep 更直观!
```

### 6.4 如何写一个简单的内核模块

```c
// 📄 hello.c - 你的第一个内核模块!
#include <linux/module.h>    // 所有模块都需要
#include <linux/kernel.h>    // printk()
#include <linux/init.h>      // __init, __exit

// 模块加载时调用
static int __init hello_init(void)
{
    printk(KERN_INFO "Hello, Orange Pi kernel! 🍊\n");
    // KERN_INFO: 日志级别
    // 级别从高到低: KERN_EMERG, KERN_ALERT, KERN_CRIT, KERN_ERR,
    //               KERN_WARNING, KERN_NOTICE, KERN_INFO, KERN_DEBUG
    return 0;  // 返回 0 表示成功
}

// 模块卸载时调用
static void __exit hello_exit(void)
{
    printk(KERN_INFO "Goodbye, Orange Pi kernel! 👋\n");
}

module_init(hello_init);    // 注册加载函数
module_exit(hello_exit);    // 注册卸载函数

MODULE_LICENSE("GPL");      // 许可证 (必须!)
MODULE_AUTHOR("Your Name"); // 作者信息
MODULE_DESCRIPTION("My first kernel module");
```

**编译模块的 Makefile**:
```makefile
# 指向你的内核源码目录
KERNEL_DIR := /home/gaoyubo/linux-orangepi

obj-m := hello.o    # 模块名.o (注意: 是 obj-m, 不是 obj-y!)

all:
	make -C $(KERNEL_DIR) M=$(PWD) ARCH=arm64 \
		CROSS_COMPILE=aarch64-linux-gnu- modules

clean:
	make -C $(KERNEL_DIR) M=$(PWD) clean
```

**测试**:
```bash
# 在 Orange Pi 上:
insmod hello.ko            # 加载模块
dmesg | tail               # 看到 "Hello, Orange Pi kernel! 🍊"
rmmod hello                # 卸载模块
dmesg | tail               # 看到 "Goodbye, Orange Pi kernel! 👋"
```

---

## 第七章：学习路线图

### 阶段一：理解"是什么" (1-2 周)

```
☐ 能说出内核的 5 大子系统 (进程/内存/文件系统/网络/驱动)
☐ 能看懂设备树的基本语法
☐ 能成功编译和部署内核
☐ 会使用 dmesg, lsmod, uname 等基本命令
☐ 能用 grep 在源码中找到想看的代码

📖 推荐阅读顺序:
  1. 本指南第一、二章
  2. Documentation/arm64/booting.rst
  3. 你的板子的设备树 (sun50i-h5-orangepi-prime.dts)
```

### 阶段二：跟踪启动流程 (2-4 周)

```
☐ 理解 U-Boot → 内核的交接过程
☐ 能跟踪 start_kernel() 中的主要初始化步骤
☐ 理解设备树匹配机制 (compatible → machine_desc → setup_arch)
☐ 知道 PID=0 (idle) 和 PID=1 (init) 是怎么创建的

📖 关键文件:
  - init/main.c (start_kernel 函数)
  - arch/arm64/kernel/head.S (汇编入口)
  - arch/arm64/kernel/setup.c (setup_arch)
```

### 阶段三：深入一个子系统 (4-8 周)

```
选择你最感兴趣的方向:

🎯 驱动方向:
  ☐ 理解 platform driver 模型
  ☐ 读一个简单驱动 (如 leds-gpio.c)
  ☐ 读 dwmac-sun8i.c 理解网卡驱动
  ☐ 自己写一个简单的 GPIO 驱动

🎯 网络方向:
  ☐ 理解 sk_buff (网络数据包结构)
  ☐ 理解 netfilter 框架
  ☐ 理解 TCP/IP 协议栈在 kernel 中的实现

🎯 文件系统方向:
  ☐ 理解 VFS 层
  ☐ 读一个简单文件系统 (如 ramfs)
  ☐ 理解 ext4 的磁盘布局

📖 推荐书籍:
  - 《Linux 内核设计与实现》(Robert Love) ← 入门必读!
  - 《Linux 设备驱动程序》第三版 (LDD3) ← 驱动必读!
```

### 阶段四：实战 (持续学习)

```
☐ 为 Orange Pi 添加一个新的外设支持
☐ 修改设备树, 调整引脚功能
☐ 移植一个驱动到你的内核版本
☐ 向 linux-sunxi 社区提交一个补丁
☐ 理解一个完整子系统的实现 (如 MMC 子系统)
```

---

## 第八章：常见问题 FAQ

### Q: 编译报错 "openssl/bio.h: No such file or directory"
```bash
sudo apt install libssl-dev
```

### Q: 编译报错 "No rule to make target ... regulatory.db"
这是 defconfig 里引用了外部固件文件。解决方法：
```bash
# 编辑 .config, 清空固件配置
CONFIG_EXTRA_FIRMWARE=""
CONFIG_EXTRA_FIRMWARE_DIR=""
```

### Q: 新内核无法启动, 串口无输出
常见原因：
- 使用了未压缩的 `Image` 而非 `Image.gz` (U-Boot 内存布局冲突)
- 设备树不匹配 (用了错误的 .dtb)
- 网卡驱动没编译进内核 (用 `grep CONFIG_DWMAC .config` 确认)

### Q: printk 的输出不显示在控制台
- 检查 `console=` 内核参数
- printk 的日志级别要 >= 控制台级别
- `echo 8 > /proc/sys/kernel/printk` 提高控制台级别

### Q: 如何确认驱动是否加载成功?
```bash
dmesg | grep -i "your_driver"   # 看驱动加载日志
ls /sys/bus/platform/drivers/   # 看已注册的 platform 驱动
cat /proc/device-tree/model     # 确认设备树加载正确
```

---

## 附录 A: 推荐资源

### 在线工具
| 工具 | 链接 | 用途 |
|------|------|------|
| Elixir 代码浏览 | https://elixir.bootlin.com/ | 在线看内核源码, 跳转定义/引用 |
| Linux Cross Reference | https://lxr.linux.no/ | 另一个在线代码浏览器 |
| Device Tree Spec | https://devicetree-specification.readthedocs.io/ | 设备树官方规范 |
| ARM 架构手册 | https://developer.arm.com/documentation | ARMv8-A 架构参考 |

### 书籍
| 书名 | 难度 | 适合阶段 |
|------|------|---------|
| 《Linux 内核设计与实现》 | ⭐⭐ | 入门必备 |
| 《Linux 设备驱动程序》LDD3 | ⭐⭐⭐ | 驱动开发 |
| 《深入理解 Linux 内核》 | ⭐⭐⭐⭐ | 进阶深入 |
| 《奔跑吧 Linux 内核》 | ⭐⭐⭐ | ARM 架构实战 |

### 社区
- [linux-sunxi](https://linux-sunxi.org/) — Allwinner Linux 社区, 有详细的芯片文档
- [Orange Pi 论坛](https://forum.orangepi.org/)
- [Linux Kernel Mailing List](https://lkml.org/) — 内核开发讨论
- [内核新手邮件列表](https://kernelnewbies.org/) — 新人友好的内核社区

---

## 附录 B: 本项目的完整编译记录

```bash
# 项目路径
cd /home/gaoyubo/linux-orangepi

# 环境
Ubuntu 24.04, GCC 13.3.0 (aarch64-linux-gnu-)

# 配置
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- orangepi_defconfig

# 编译
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image.gz
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) modules
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) dtbs

# 编译产物
# arch/arm64/boot/Image      23MB  未压缩内核镜像
# arch/arm64/boot/Image.gz   9.1MB gzip 压缩内核
# vmlinux                    25MB  ELF 格式 (含符号, 调试用)
# System.map                 3.9MB 符号地址映射
```

> ⚠️ 部署到 Orange Pi 时请使用 **Image.gz**，不要用未压缩的 Image！

---

*📅 最后更新: 2024-06-24 | 适用内核: 5.4.65 | 目标板: Orange Pi Prime (Allwinner H5)*
