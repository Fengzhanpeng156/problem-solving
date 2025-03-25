## U-BOOT移植



### 1 查找默认配置文件



mx6ull_14x14_evk_emmc_defconfig

先编译

```
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- mx6ull_14x14_evk_emmc_defconfig 
make V=1 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j16
```



将bin文件烧写到sd卡

需要解决LCD与网络驱动适配问题

### 2 在U-BOOT添加自己的开发板



#### configs/下创建配置文件mx6ull_alientek_emmc_defconfig



```
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



```
cp include/configs/mx6ullevk.h include/configs/mx6ull_alientek_emmc.h
```



7，8行改为

```
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



```
PLUGIN board/freescale/mx6ullevk/plugin.bin 0x00907000
```

改为

```
PLUGIN board/freescale/mx6ull_alientek_emmc /plugin.bin 0x00907000
```

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

- `board/freescale/mx6ull_alientek_emmc/` 该目录包含 **i.MX6ULL Alientek（正点原子）EMMC 版本开发板** 的 U-Boot 代码。
- `include/configs/mx6ull_alientek_emmc.h` 该头文件包含 U-Boot 的特定配置，如引导参数、存储设备配置等。
- `configs/mx6ull_alientek_emmc_defconfig` 这是 **默认的 U-Boot 配置文件**，用于构建 U-Boot 时的基本配置选项。

```
MX6ULLEVK BOARD
M:	Peng Fan <peng.fan@nxp.com>
S:	Maintained
F:	board/freescale/mx6ull_alientek_emmc/
F:	include/configs/mx6ull_alientek_emmc.h
F:	configs/mx6ull_alientek_emmc_defconfig
```



### 4 修改U-BOOT图形配置文件



修改文件 `arch/arm/cpu/armv7/mx6/Kconfig`

207行添加

```
config TARGET_MX6ULL_ALIENTEK_EMMC
	bool "Support mx6ull_alientek_emmc"
	select MX6ULL
	select DM
	select DM_THERMAL
```



最后end if 之前添加

```
source "board/freescale/mx6ull_alientek_emmc/Kconfig"
```

### 5 LCD驱动修改



一般 uboot中修改驱动基本都是在 xxx.h和 xxx.c这两个文件中进行的， xxx为板子名称，比如 mx6ull_alientek_emmc.h和 mx6ull_alientek_emmc.c这两个文件。

一般修改 LCD驱动重点注意以下几点： ①、 LCD所使用的 GPIO，查看 uboot中 LCD的 IO配置是否正确。 ②、 LCD背光引脚 GPIO的配置。 ③、 LCD配置参数是否正确。

- 打开文件 mx6ull_alientek_emmc.c

 780行

```
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



```
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

 **像素时钟31MHz**



name ：LCD名字，要和环境变量中的 panel相等

 xres、 yres ：LCD X轴和 Y轴像素数量。 

pixclock：像素时钟，每个像素时钟周期的长度，单位为皮秒。

 left_margin HBP，水平同步后肩。

 right_margin HFP，水平同步前肩。

 upper_margin VBP，垂直同步后肩。

 lower_margin VFP，垂直同步前肩。

 hsync_len HSPW，行同步脉宽。 

vsync_len VSPW，垂直同步脉宽。 

vmode 大多数使用 FB_VMODE_NONINTERLACED，也就是不使用隔行扫描。

**以正点原子的 7寸 1024\*600分辨率的屏幕 (ATK7016)为例， 屏幕要求的像素时钟为 51.2MHz，因此pixclock=(1/51200000)\*10^12=19531**

- 打开 mx6ull_alientek_emmc.h

  panel=TFT43AB改为panel=TFT4384

panel的值要与 .name成员变量的值一致。

这是因为之前有将环境变量保存到 EMMC中， uboot启动以后会先从 EMMC中读取环境变量，如果 EMMC中没有环境变量的话才会使用 mx6ull_alientek_emmc.h中的默认环境变量。
如果 EMMC中的环境变量 panel不等于 TFT4384，那么 LCD显示肯定不正常，我们只需要在uboot中修改 panel的值为 TFT4384即可

```
setenv panel TFT7016 
saveenv
```

