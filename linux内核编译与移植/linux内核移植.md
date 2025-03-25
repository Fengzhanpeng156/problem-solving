# 1 创建VSCODE工程

1 将nxp官方linux内核传到ubuntu

2 解压缩 ```tar -vxjf XXXXXXX```

# 2 编译官方开发板对应的内核

默认配置文件存放路径 ```arc/arm/configs```

最终编译出zImage和 imx6ull-14x14-evk-emmc.dtb和imx6ull-14x14-evk.dtb

将zImage和 imx6ull-14x14-evk-emmc.dtb拷贝到tftpboot下，再用uboot通过tftp启动

NXP官方的可以在正点原子上启动。

# 3 在linux中添加自己开发板

1 需要一个imx6ull-alientek-emmc-defconfig默认配置文件

2 imx6ull-alientek-emmc编译出来的dtb文件

```bash
(base) feng@os:~/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga$ cd arch/arm/configs/
(base) feng@os:~/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga/arch/arm/configs$ cp imx_v7_mfg_defconfig imx_alientek_emmc_defconfig
```

```bash
(base) feng@os:~/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga/arch/arm/boot$ cd dts/
(base) feng@os:~/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga/arch/arm/boot/dts$ cp imx6ul-14x14-evk.dts imx6ull-alientek-emmc.dts
```

**ATTENTION**

**是复制dts文件不是dtb文件**



3 修改arch/arm/boot/dts/Makefile,添加```imx6ull-alientek-emmc.dtb \```

" \ "后不能有空格

# 4 CPU主频与网络驱动修改

1 修改驱动之前，保证能正常启动

2 根文件系统处理好，使用现成根文件系统。保证emmc烧写了系统。设置boorcmd和bootargs

bootcmd设置默认从网络启动

```setenv bootcmd 'tftp 80800000 zImage;tftp 83000000 imx6ull-alientek-emmc.dtb;bootz 80800000 - 83000000;'```

```saveenv```

bootargs 设置，根文件系统存放在emmc分区2，

```setenv bootargs 'console=ttymxc0,115200 root=/dev/mmcblk1p2 rootwait rw'```

```saveenv```

出现error

```VFS: Cannot open root device "mmcblk1p2" or unknown-block(0,0): error -6```

EMMC驱动有问题

在imx6ull-alientek-emmc.dts中找到usdhc2节点，将usdhc2改为

```
&usdhc2 {
	pinctrl-names = "default", "state_100mhz", "state_200mhz";
	pinctrl-0 = <&pinctrl_usdhc2_8bit>;
	pinctrl-1 = <&pinctrl_usdhc2_8bit_100mhz>;
	pinctrl-2 = <&pinctrl_usdhc2_8bit_200mhz>;
	bus-width = <8>;
	non-removable;
	status = "okay";
};
```

代码来源于imx6ull-14x14-evk-emmc.dts

修改后，```make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs```

配置主频，超频到696MHz

# 5 使能8线emmc

修改设备树 imx6ull-alientek-emmc.dts。节点usdhc2

```
&usdhc2 {
	pinctrl-names = "default", "state_100mhz", "state_200mhz";
	pinctrl-0 = <&pinctrl_usdhc2_8bit>;
	pinctrl-1 = <&pinctrl_usdhc2_8bit_100mhz>;
	pinctrl-2 = <&pinctrl_usdhc2_8bit_200mhz>;
	bus-width = <8>;
	non-removable;
	status = "okay";
```

# 6 网络驱动修改

Linux驱动开发一般通过网络调试

ifconfig eth1 up没有任何输出显示

使用```ifconfig eth1 up && dmesg | tail -n 10```







