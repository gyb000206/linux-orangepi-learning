// SPDX-License-Identifier: GPL-2.0
/*
 * hello.c - 第一个内核模块示例 🍊
 *
 * 📖 学习要点:
 *   1. module_init() / module_exit() - 模块的加载和卸载入口
 *   2. printk() - 内核日志输出 (用 dmesg 查看)
 *   3. MODULE_LICENSE / MODULE_AUTHOR - 模块元信息
 *   4. __init / __exit - 告诉内核这些函数用完可以释放
 *
 * 编译: make -C /path/to/kernel M=$(pwd) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
 * 测试: insmod hello.ko → dmesg → rmmod hello.ko → dmesg
 */

#include <linux/module.h>      // 所有内核模块都需要
#include <linux/kernel.h>      // printk(), pr_info()
#include <linux/init.h>        // __init, __exit 宏
#include <linux/moduleparam.h> // module_param() 模块参数

/* =============================================
 * 模块参数: 可在加载时通过 insmod hello.ko name="world" 传入
 * ============================================= */
static char *name = "Orange Pi";
module_param(name, charp, S_IRUGO);
MODULE_PARM_DESC(name, "要问候的名字 (如: insmod hello.ko name=\"world\")");

/* =============================================
 * 模块初始化函数
 *
 * 在 insmod 时自动调用
 * 返回 0 表示成功，负值表示失败
 *
 * __init 标记: 此函数在初始化完成后会被释放
 * ============================================= */
static int __init hello_init(void)
{
    // KERN_INFO: 日志级别 (最高 KERN_EMERG, 最低 KERN_DEBUG)
    // 用 dmesg | tail 查看输出
    pr_info("========================================\n");
    pr_info("  Hello, %s! 👋\n", name);
    pr_info("  内核版本: %s\n", init_uts_ns.name.release);
    pr_info("  CPU: %s\n", init_uts_ns.name.machine);
    pr_info("========================================\n");

    pr_debug("这是调试消息 (需要启用 dynamic debug 才能看到)\n");

    return 0;
}

/* =============================================
 * 模块退出函数
 *
 * 在 rmmod 时自动调用
 *
 * __exit 标记: 编译进内核时此函数会被丢弃 (不能卸载)
 * ============================================= */
static void __exit hello_exit(void)
{
    pr_info("Goodbye, %s! 内核模块已卸载 👋\n", name);
}

/* 注册模块入口和出口 */
module_init(hello_init);
module_exit(hello_exit);

/* =============================================
 * 模块元信息 (必须!)
 * ============================================= */
MODULE_LICENSE("GPL");                          // 许可证 (必须声明)
MODULE_AUTHOR("Orange Pi Learner");             // 作者
MODULE_DESCRIPTION("A simple kernel module example"); // 描述
MODULE_VERSION("1.0");                          // 版本号
