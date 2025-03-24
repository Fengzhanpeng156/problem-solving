**问题描述**
在 /etc/profile 添加了 export PATH=$PATH:/usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/bin，但终端仍然找不到 arm-linux-gnueabihf-gcc

**解决方案：**
/etc/profile 适用于 登录 Shell（即 ssh 远程登录或 su - 登录），但不会自动应用于非登录 Shell
我使用的是VScode连接WSL，默认启动的是 非登录 Shell，它只会加载 ~/.bashrc，而不会加载 /etc/profile，所以修改 /etc/profile 后无效，而 ~/.bashrc 可以生效。
在 ~/.bashrc 里修改 PATH
```bash
export PATH=/usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/bin:$PATH
```
```bash
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

```assembly
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

## U-BOOT移植

### 1 查找默认配置文件

mx6ull_14x14_evk_emmc_defconfig

先编译

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- mx6ull_14x14_evk_emmc_defconfig 
make V=1 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j16
```

将bin文件烧写到sd卡

需要解决LCD与网络驱动适配问题

### 2 在U-BOOT添加自己的开发板

#### configs/下创建配置文件mx6ull_alientek_emmc_defconfig

```bash
cd configs 
cp mx6ull_14x14_evk_emmc_defconfig mx6ull_alientek_emmc_defconfig
```

```
CONFIG_SYS_EXTRA_OPTIONS="IMX_CONFIG=board/freescale/mx6ull_alientek_emmc/imximage.cfg,MX6ULL_EVK_EMMC_REWORK"
CONFIG_ARM=y
CONFIG_ARCH_MX6=y
CONFIG_TARGET_MX6ULL_ALIENTEK_EMMC=y
CONFIG_CMD_GPIO=y
```

将配置文件中文件名改为自己文件

#### 添加开发板对应头文件

```bash
cp include/configs/mx6ullevk.h include/configs/mx6ull_alientek_emmc.h
```

7，8行改为

```c
#ifndef __MX6ULL_ALIENTEK_EMMC_CONFIG_H
#define __MX6ULL_ALIENTEK_EMMC_CONFIG_H
```

mx6ull_alientek_emmc.h文件中基本都是“ CONFIG_”开头的宏定义，这也说明 mx6ull_alientek_emmc.h文件的主要功能就是配置或者裁剪 uboot。

### 3 添加开发板对应的板级文件夹

uboot中每个板子都有一个对应的文件夹来存放板级文件，比如开发板上外设驱动文件等等。

将原版复制一份，重命名为自己的板子名，在此基础上进行相关文件修改。

```
cd board/freescale/
cp mx6ullevk/ -r mx6ull_alientek_emmc
```

```
cd mx6ull_alientek_emmc 
mv mx6ullevk.c mx6ull_alientek_emmc.c
```

#### 3.1 修改Makefile文件

重点是第 6行的 obj-y，改为 mx6ull_alientek_emmc.o，这样才会编译 mx6ull_alientek_emmc.c这个文件。

#### 3.2 修改mx6ull_alientek_emmc下的imximage.cfg

```PLUGIN board/freescale/mx6ullevk/plugin.bin 0x00907000```

改为

```PLUGIN board/freescale/mx6ull_alientek_emmc /plugin.bin 0x00907000```

#### 3.3 修改mx6ull_alientek_emmc下的Kconfig

主要是修改板子名字，如下

```
if TARGET_MX6ULL_ALIENTEK_EMMC 

config SYS_BOARD
	default "mx6ull_alientek_emmc"

config SYS_VENDOR
	default "freescale"

config SYS_CONFIG_NAME
	default "mx6ull_alientek_emmc"

endif

```

#### 3.4 修改mx6ull_alientek_emmc下的MAINTAINERS

**F: ...**（Files）：列出与该开发板相关的 U-Boot 源代码文件，包括：

- `board/freescale/mx6ull_alientek_emmc/`
   该目录包含 **i.MX6ULL Alientek（正点原子）EMMC 版本开发板** 的 U-Boot 代码。
- `include/configs/mx6ull_alientek_emmc.h`
   该头文件包含 U-Boot 的特定配置，如引导参数、存储设备配置等。
- `configs/mx6ull_alientek_emmc_defconfig`
   这是 **默认的 U-Boot 配置文件**，用于构建 U-Boot 时的基本配置选项。

```
MX6ULLEVK BOARD
M:	Peng Fan <peng.fan@nxp.com>
S:	Maintained
F:	board/freescale/mx6ull_alientek_emmc/
F:	include/configs/mx6ull_alientek_emmc.h
F:	configs/mx6ull_alientek_emmc_defconfig
```

### 4 修改U-BOOT图形配置文件

修改文件
```arch/arm/cpu/armv7/mx6/Kconfig```

207行添加

```
config TARGET_MX6ULL_ALIENTEK_EMMC
	bool "Support mx6ull_alientek_emmc"
	select MX6ULL
	select DM
	select DM_THERMAL
```

最后end if 之前添加

```source "board/freescale/mx6ull_alientek_emmc/Kconfig"```

### 5 LCD驱动修改

一般 uboot中修改驱动基本都是在 xxx.h和 xxx.c这两个文件中进行的， xxx为板子名称，比如 mx6ull_alientek_emmc.h和 mx6ull_alientek_emmc.c这两个文件。

一般修改 LCD驱动重点注意以下几点：
①、 LCD所使用的 GPIO，查看 uboot中 LCD的 IO配置是否正确。
②、 LCD背光引脚 GPIO的配置。
③、 LCD配置参数是否正确。

- 打开文件 mx6ull_alientek_emmc.c

​	780行

```c
struct display_info_t const displays[] = {{
	.bus = MX6UL_LCDIF1_BASE_ADDR,
	.addr = 0,
	.pixfmt = 24,
	.detect = NULL,
	.enable	= do_enable_parallel_lcd,
	.mode	= {
		.name			= "TFT4384",
		.xres           = 800,
		.yres           = 480,
		.pixclock       = 32258,
		.left_margin    = 88,
		.right_margin   = 40,
		.upper_margin   = 32,
		.lower_margin   = 13,
		.hsync_len      = 48,
		.vsync_len      = 3,
		.sync           = 0,
		.vmode          = FB_VMODE_NONINTERLACED
} } };
```

```c
      /*.name			= "TFT4384",
		.xres           = 800,
		.yres           = 480,
		.pixclock       = 32258,
		.left_margin    = 88,
		.right_margin   = 40,
		.upper_margin   = 32,
		.lower_margin   = 13,
		.hsync_len      = 48,
		.vsync_len      = 3,*/
主要修改这部分参数
```

![image-20250324141755987](E:\遇到问题\problem-solving\图片\LCD参数)

​            **像素时钟31MHz**

name ：LCD名字，要和环境变量中的 panel相等。
xres、 yres ：LCD X轴和 Y轴像素数量。
pixclock：像素时钟，每个像素时钟周期的长度，单位为皮秒。
left_margin HBP，水平同步后肩。
right_margin HFP，水平同步前肩。
upper_margin VBP，垂直同步后肩。
lower_margin VFP，垂直同步前肩。
hsync_len HSPW，行同步脉宽。
vsync_len VSPW，垂直同步脉宽。
vmode 大多数使用 FB_VMODE_NONINTERLACED，也就是不使用隔行扫描。

**以正点原子的 7寸 1024*600分辨率的屏幕 (ATK7016)为例，
屏幕要求的像素时钟为 51.2MHz，因此pixclock=(1/51200000)*10^12=19531**

- 打开 mx6ull_alientek_emmc.h

  panel=TFT43AB改为panel=TFT4384

panel的值要与 .name成员变量的值一致。
