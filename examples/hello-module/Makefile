# SPDX-License-Identifier: GPL-2.0
#
# Makefile - 外部内核模块编译示例
#
# 📖 使用说明:
#   1. 在 Orange Pi 上编译 (本地编译):
#      make -C /lib/modules/$(uname -r)/build M=$(pwd) modules
#
#   2. 交叉编译 (在 x86 电脑上为 ARM64 编译):
#      make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
#           -C /path/to/linux-orangepi M=$(pwd) modules
#
#   3. 清理:
#      make clean
#
#   4. 测试:
#      sudo insmod hello.ko          # 加载模块
#      sudo insmod hello.ko name="world"  # 带参数加载
#      dmesg | tail -5               # 查看输出
#      sudo rmmod hello.ko           # 卸载模块
#      dmesg | tail -3               # 查看卸载输出
#

# 内核源码路径 (运行中的内核)
KERNEL_DIR ?= /lib/modules/$(shell uname -r)/build

# 要编译的模块 (obj-m = 可加载模块, obj-y = 编译进内核)
obj-m := hello.o

# 如果你的模块由多个 .c 文件组成:
# hello-objs := file1.o file2.o

all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean

# =============================================
# 交叉编译示例 (当前文件被注释)
# =============================================
# 用法: make -f Makefile.cross
# .PHONY: cross
# cross:
# 	$(MAKE) ARCH=arm64 \
# 		CROSS_COMPILE=aarch64-linux-gnu- \
# 		-C /home/gaoyubo/linux-orangepi \
# 		M=$(PWD) modules
