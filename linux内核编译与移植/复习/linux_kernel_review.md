# 1 创建工程

1 将nxp官方linux内核传到ubuntu

2 解压缩 ```tar -vxjf XXXXXXX```

# 2 编译官方内核

检查是否能用

修改Makefile

```C
ARCH		?= arm
CROSS_COMPILE	?= arm-linux-gnueabihf-
```

# 3 在linux中添加自己的开发板

```shell
feng@os:~/linux/alientek_review/linux_kernel/linux-imx-rel_imx_4.1.15_2.1.0_ga$ cd arch/arm/configs/
feng@os:~/linux/alientek_review/linux_kernel/linux-imx-rel_imx_4.1.15_2.1.0_ga/arch/arm/configs$ cp imx_v7_mfg_defconfig imx_alientek_emmc_defconfig
```

- 添加默认配置文件

打开imx_alientek_emmc_defconfig文件，找到“ CONFIG_ARCH_MULTI_V6=y”这一行将其屏蔽掉

- 添加对应设备树文件

```sh
feng@os:~/linux/alientek_review/linux_kernel/nxp-linux$ cd arch/arm/boot/dts/
feng@os:~/linux/alientek_review/linux_kernel/nxp-linux/arch/arm/boot/dts$ cp imx6ull-14x14-evk.dts imx6ull_alientek_emmc.dts
```

- 创建好以后我们还需要修改文件 arch/arm/boot/dts/Makefile

```C
dtb-$(CONFIG_SOC_IMX6ULL) += \
	imx6ull-14x14-ddr3-arm2.dtb \
	imx6ull-14x14-ddr3-arm2-adc.dtb \
	imx6ull-14x14-ddr3-arm2-cs42888.dtb \
	imx6ull-14x14-ddr3-arm2-ecspi.dtb \
	imx6ull-14x14-ddr3-arm2-emmc.dtb \
	imx6ull-14x14-ddr3-arm2-epdc.dtb \
	imx6ull-14x14-ddr3-arm2-flexcan2.dtb \
	imx6ull-14x14-ddr3-arm2-gpmi-weim.dtb \
	imx6ull-14x14-ddr3-arm2-lcdif.dtb \
	imx6ull-14x14-ddr3-arm2-ldo.dtb \
	imx6ull-14x14-ddr3-arm2-qspi.dtb \
	imx6ull-14x14-ddr3-arm2-qspi-all.dtb \
	imx6ull-14x14-ddr3-arm2-tsc.dtb \
	imx6ull-14x14-ddr3-arm2-uart2.dtb \
	imx6ull-14x14-ddr3-arm2-usb.dtb \
	imx6ull-14x14-ddr3-arm2-wm8958.dtb \
	imx6ull-14x14-evk.dtb \
	imx6ull-14x14-evk-btwifi.dtb \
	imx6ull-14x14-evk-emmc.dtb \
	imx6ull-14x14-evk-gpmi-weim.dtb \
	imx6ull-14x14-evk-usb-certi.dtb \
	imx6ull-alientek-emmc.dts \    //HERE
	imx6ull-9x9-evk.dtb \
	imx6ull-9x9-evk-btwifi.dtb \
	imx6ull-9x9-evk-ldo.dtb
```

- 编译测试

前面Makefile已经写死

所以编写sh

```sh
#!/bin/bash
make distclean
make imx_alientek_emmc_defconfig
make menuconfig
make -j8
```

```bash
 OBJCOPY arch/arm/boot/zImage
 Kernel: arch/arm/boot/zImage is ready
```

# 4 CPU主频与网络驱动

- 网络

修改 SR8201F的复位以及网络时钟引脚驱动

修改 fec1和 fec2节点的 pinctrl-0属性

修改 SR8201F的 PHY地址

**在嵌入式系统或网络设备中，**PHY 地址 是指用于在 MAC 控制器（Media Access Controller）与 PHY 芯片（物理层芯片）之间通信时，标识不同 PHY 芯片的地址。

```C
phy-handle = <&phy0>;
phy0: ethernet-phy@1 {
    reg = <1>;  // 这个“1”就是 PHY 地址
}
```

- 、修改 fec_main.c文件

drivers/net/ethernet/freescale/fec_main.c，找到函数fec_reset_phy

加入```msleep(200)```

根据 SR8201F收据手册上的要求， SR8201F在复位结束以后需要等待至少 150ms才能操作 SR8201F，因此这里添加了一个 200ms的延时。

# 5 根文件系统

- 使用busybox

1 修改Makefile

```
CROSS_COMPILE ?= /usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-
```

```
ARCH ?= arm
```

2 中文字符支持

修改  /libbb/printable_string.c，31，32行，注释掉

```
		// if (c >= 0x7f)
		// 	break;
```

45-47行修改

```
			// if (c < ' ' || c >= 0x7f)
			if(c < ' ')
				*d = '?';
```

/libbb/unicode.c文件



1022行改为

```
				// *d++ = (c >= ' ' && c < 0x7f) ? c : '?';
				*d++ = (c >= ' ') ? c : '?';
```

1031行

	// if (c < ' ' || c >= 0x7f)
				if (c < ' ')

3 配置busybox

make defconfig生成默认配置文件

make menuconfig进行图形化配置

配置路径：

```
Location:
	-> Settings 
			-> Build static binary (no shared libs)
```

选项“
Build static binary (no shared libs)”用来决定是静态编译 busybox还是动态编译，静态编译的话就不需要库文件，但是编译出来的库会很大。动态编译的话要求根文件系统中有库文件，但是编译出来的 busybox会小很多。这里我们不能采用静态编译！因为采用静态编译的话 DNS会出问题！无法进行域名解析，配置如图

```
Location: -> Linux Module Utilities -> Simplified modutils
默认会选中“Simplified modutils”，这里我们要取消勾选！！
```

- 编译

```
make 
make install CONFIG_PREFIX=/存放路径
```

- 向根文件系统添加lib库

```C
进入/usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/arm-linux-gnueabihf/libc/lib
```

```bash
cp *so* *.a /根文件系统/lib/ -d
```

```bash
rm ld-linux-armhf.so.3
```

```bash
cp ld-linux-armhf.so.3 /根文件系统/lib/
```

进入```/usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/arm-linux-gnueabihf/lib```

```
cp *so* *.a /根文件系统/lib/ -d
```



库文件就是交叉编译器

添加rootfs/lib目录

添加rootfs/usr/lib

将```/usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/arm-linux-gnueabihf/libc/ usr/lib```复制到、usr/lib

创建其他文件夹dev、 proc、 mnt、 sys、 tmp和 root

# 6 完善根文件系统

- 创建 /etc/init.d/rcS文件

```SH
#!/bin/sh

PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/lib
export PATH LD_LIBRARY_PATH

mount -a
mkdir /dev/pts
mount -t devpts devpts /dev/pts

echo /sbin/mdev > /proc/sys/kernel/hotplug
mdev -s

# ./hello &
```

给可执行权限

- 创建 /etc/fstab文件

在 rootfs中创建 /etc/fstab文件， fstab在 Linux开机以后自动配置哪些需要自动挂载的分区，
格式如下：

```
<file system> <mount point> <type> <options> <dump> <pass>
```

```
#<file system>	<mount point>	<type>	<options>	<dump>	<pass>
proc		/proc		proc	defaults	0	0
tmpfs		/tmp		tmpfs	defaults	0	0
sysfs		/sys		sysfs	defaults	0	0
	
```

- 创建 /etc/inittab文件



```
#etc/inittab
::sysinit:/etc/init.d/rcS
console::askfirst:-/bin/sh
::restart:/sbin/init
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
::shutdown:/sbin/swapoff -a
```

