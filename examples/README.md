# examples/ — 内核学习示例代码

本目录包含动手练习的示例代码，配合学习指南使用。

## 📦 内容

| 示例 | 说明 | 难度 |
|------|------|------|
| [`hello-module/`](hello-module/) | 第一个内核模块 — 加载/卸载/参数传递 | ⭐ 入门 |

## 使用方法

### 在 Orange Pi 上直接编译

```bash
cd examples/hello-module
make KERNEL_DIR=/lib/modules/$(uname -r)/build
sudo insmod hello.ko
sudo insmod hello.ko name="world"   # 带参数
dmesg | tail -5
sudo rmmod hello.ko
```

### 交叉编译 (在本机为 Orange Pi 编译)

```bash
cd examples/hello-module
make -C /home/gaoyubo/linux-orangepi M=$(pwd) \
     ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules
```

然后将生成的 `.ko` 文件传到 Orange Pi 上测试。
