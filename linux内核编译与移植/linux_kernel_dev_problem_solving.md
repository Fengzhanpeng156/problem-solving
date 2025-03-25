**问题描述** 在 /etc/profile 添加了 export PATH=$PATH:/usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/bin，但终端仍然找不到 arm-linux-gnueabihf-gcc

**解决方案：** /etc/profile 适用于 登录 Shell（即 ssh 远程登录或 su - 登录），但不会自动应用于非登录 Shell 我使用的是VScode连接WSL，默认启动的是 非登录 Shell，它只会加载 ~/.bashrc，而不会加载 /etc/profile，所以修改 /etc/profile 后无效，而 ~/.bashrc 可以生效。 在 ~/.bashrc 里修改 PATH

```
export PATH=/usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/bin:$PATH
```



```
source ~/.bashrc
```



**问题描述**

WSL下无法挂载物理意义上的U盘，fdisk找不到

https://learn.microsoft.com/zh-cn/windows/wsl/connect-usb

## 链接脚本u-boot.lds



u-boot.map中，

```
.text           0x0000000087800000    0x3cd64
 *(.__image_copy_start)
 .__image_copy_start
                0x0000000087800000        0x0 arch/arm/lib/built-in.o
                0x0000000087800000                __image_copy_start
 *(.vectors)
 .vectors       0x0000000087800000      0x300 arch/arm/lib/built-in.o
```



**`.text` 段的起始地址 = `0x87800000`**。

**`\*(.__image_copy_start)`**：

- `__image_copy_start` 是一个特殊标记，用于指示**镜像的起始地址**。
- 它不会占用实际空间，但它的值会被设定为当前地址（`0x87800000`）。

**`\*(.vectors)`**：

- `.vectors` 段紧随 `__image_copy_start`，也存放在 `0x87800000`。
- `.vectors` 主要存放**中断向量表（IVT）**，它的大小是 `0x300`（768 字节）。

**`__image_copy_start` 只是一个标记符号，它指向 `.text` 段的起始地址**，因此它的地址是 `0x87800000`。

**`\*(.vectors)` 确实存储了数据，并且它也从 `0x87800000` 开始，因此两者地址相同**。

如果 Bootloader 运行在 Flash 但需要把代码复制到 RAM 运行，就可以通过 `__image_copy_start` 确定需要拷贝的起始地址。

```
_start:

#ifdef CONFIG_SYS_DV_NOR_BOOT_CFG
	.word	CONFIG_SYS_DV_NOR_BOOT_CFG
#endif

	b	reset
	ldr	pc, _undefined_instruction
	ldr	pc, _software_interrupt
	ldr	pc, _prefetch_abort
	ldr	pc, _data_abort
	ldr	pc, _not_used
	ldr	pc, _irq
	ldr	pc, _fiq
```



`b`（branch）表示 **无条件跳转**。

该指令会让 CPU **立即跳转到 `save_boot_params` 处执行**，不会返回。

```
	mrs	r0, cpsr
	and	r1, r0, #0x1f		@ mask mode bits
	teq	r1, #0x1a		@ test for HYP mode
	bicne	r0, r0, #0x1f		@ clear all mode bits
	orrne	r0, r0, #0x13		@ set SVC mode
	orr	r0, r0, #0xc0		@ disable FIQ and IRQ
	msr	cpsr,r0
```



**代码的整体作用**

1. **读取 `CPSR`（CPU 状态寄存器）**。

2. 检查 CPU 是否处于 HYP 模式

   ：

   - 如果 **在 HYP 模式**，跳过模式修改。
   - 如果 **不是 HYP 模式**，切换到 **SVC（超级用户模式）**。

3. **禁用 IRQ 和 FIQ（防止模式切换时中断发生）**。

4. **写回 `CPSR`，正式切换到 SVC 模式**。

