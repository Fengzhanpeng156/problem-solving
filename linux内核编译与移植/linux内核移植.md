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



# 7 busybox构建根文件系统

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

```
				// if (c < ' ' || c >= 0x7f)
				if (c < ' ')
```

3 配置busybox

make defconfig生成默认配置文件

make menuconfig进行图形化配置

4 编译busybox

```
make install CONFIG_PREFIX=/home/feng/linux/nfs/rootfs
```

5 添加库文件

库文件就是交叉编译器

添加rootfs/lib目录

添加rootfs/usr/lib

创建其他文件夹dev、 proc、 mnt、 sys、 tmp和 root



完整开发会使用Buildroot等



# 8 根文件系统测试 NFS方式

1 linux系统内核网络驱动要正常

2 设置uboot的bootargs，也就是linux内核命令行参数

```
=> setenv ipaddr 192.168.10.50
=> setenv ethaddr 00:04:9f:04:d2:35
=> setenv gatewayip 192.168.10.1
=> setenv netmask 255.255.255.0
=> setenv serverip 192.168.10.100
=> saveenv
```

```
=> setenv bootargs 'console=ttymxc0,115200 root=/dev/nfs nfsroot=192.168.10.100:/home/feng/linux/nfs/rootfs,proto=tcp rw ip=192.168.10.50:192.168.10.100:192.168.10.1:255.255.255.0::eth0:off'
```

**ATTENTION**

如果是挂载Ubuntu18系统及更高版本的系统下的nfs共享目录，uboot无法通过nfs启动Ubuntu系统内的共享目录。需要在/etc/default/nfs-kernel-server文件进行修改，改好了保存退出，然后重启一下 nfs 就可以了，或者报错Loading:*ww ERROR:File lookup fail的也是按照下面的方法来解决。

```
(base) feng@os:~$ sudo vi /etc/default/nfs-kernel-server
```

```
  1 # Number of servers to start up
  2 RPCNFSDCOUNT=8
  3 RPCNFSDCOUNT="-V 2 8"
  4 # Runtime priority of server (see nice(1))
  5 RPCNFSDPRIORITY=0
  6 
  7 # Options for rpc.mountd.
  8 # If you have a port-based firewall, you might want to set up
  9 # a fixed port here using the --port option. For more information, 
 10 # see rpc.mountd(8) or http://wiki.debian.org/SecuringNFS
 11 # To disable NFSv4 on the server, specify '--no-nfs-version 4' here
 12 #RPCMOUNTDOPTS="--manage-gids"
 13 RPCMOUNTDOPTS="-V 2 --manage-gids"
 14 # Do you want to start the svcgssd daemon? It is only required for Kerberos
 15 # exports. Valid alternatives are "yes" and "no"; the default is "no".
 16 NEED_SVCGSSD=""
 17 
 18 # Options for rpc.svcgssd.
 19 RPCSVCGSSDOPTS="--nfs-version 2,3,4 --debug --syslog"
```

**添加第3行，注释12行，添加13行，添加19行**

成功后有如下信息

```bash
mmc1: MAN_BKOPS_EN bit is not set
mmc1: new DDR MMC card at address 0001
mmcblk1: mmc1:0001 8GTF4R 7.28 GiB
mmcblk1boot0: mmc1:0001 8GTF4R partition 1 4.00 MiB
mmcblk1boot1: mmc1:0001 8GTF4R partition 2 4.00 MiB
mmcblk1rpmb: mmc1:0001 8GTF4R partition 3 512 KiB
fec 20b4000.ethernet eth0: Freescale FEC PHY driver [Generic PHY] (mii_bus:phy_addr=20b4000.ethernet:01, irq=-1)
 mmcblk1: p1 p2
IPv6: ADDRCONF(NETDEV_UP): eth0: link is not ready
fec 20b4000.ethernet eth0: Link is Up - 100Mbps/Full - flow control rx/tx
IPv6: ADDRCONF(NETDEV_CHANGE): eth0: link becomes ready
IP-Config: Complete:
     device=eth0, hwaddr=00:04:9f:04:d2:35, ipaddr=192.168.10.50, mask=255.255.255.0, gw=192.168.10.1
     host=192.168.10.50, domain=, nis-domain=(none)
     bootserver=192.168.10.100, rootserver=192.168.10.100, rootpath=
can-3v3: disabling
ALSA device list:
  No soundcards found.
VFS: Mounted root (nfs filesystem) on device 0:15.
devtmpfs: mounted
Freeing unused kernel memory: 432K (80908000 - 80974000)
can't run '/etc/init.d/rcS': No such file or directory

Please press Enter to activate this console.
/ # ls
bin      lib      mnt      root     sys      usr
dev      linuxrc  proc     sbin     tmp

```

# 9 完善根文件系统



# 10 测试

1 测试应用程序运行

编写hello.c，测试软件在ARM开发板上，因此编译需要用交叉编译器。

使用file命令查看信息，是否ARM架构

```bash
(base) feng@os:~/linux/nfs/rootfs$ file hello
hello: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 2.6.31, BuildID[sha1]=5209077b3c4d00cf811b29b6b67c834636594993, with debug_info, not stripped
```

后台运行 ./xxx &

关闭后台运行，输入ps查看pid

```
kill -9 pid号
```

2 中文字符测试

3 开机自启动

# 11 mfgtool

在Windows下运行，可以烧写uboot.imx，zImage，dtb，rootfs，通过usb烧写。

**基本原理：**

- 先向开发板ddr下载linux内核系统
- 通过前面下载到ddr中的linux系统完成烧写工作

\mfgtools\Profiles\Linux\OS Firmware下有两个文件夹 files和firmware

files里面保存最终烧写到开发板的uboot.imx，zImage，dtb，rootfs

firmware保存第一步的uboot.imx，zImage，dtb

- 烧写脚本是vbs文件

mfgtool存放默认官方开发板

**ATTENTION**

```
官方的mfgtool压缩包要放在ubuntu解压```tar -vxzf xxxxx```，windows端用7-zip解压的不能用

在ubuntu下解压完再用zip命令压缩,WINDOWS解压后能正常使用
```

vbs脚本本质是打开mfgtool2.exe，后跟一些参数，如下：

```
Set wshShell = CreateObject("WScript.shell")
wshShell.run "mfgtool2.exe -c ""linux"" -l ""eMMC"" -s ""board=sabresd"" -s ""mmc=1"" -s ""6uluboot=14x14evk"" -s ""6uldtb=14x14-evk"""
Set wshShell = Nothing

```

- mfgtool/Profile/Linux/OS Firmware/ucl2.xml文件

ucl2.xml负责在files和firmware里选合适的文件

# 12 烧写自己的系统

**1 firmware下的文件名**

firmware/u-boot-imx6ul%lite%%6uluboot%_emmc.imx为

u-boot-imx6ull14x14evk_emmc.imx                                         **uboot**

zImage不需要变名字                                                                        **zImage**

firmware/zImage-imx6ul%lite%-%6uldtb%-emmc.dtb为

zImage-imx6ull-14x14-evk-emmc.dtb                                               **dtb**

**2 files下的文件名**

files/u-boot-imx6ul%lite%%6uluboot%_emmc.imx为

u-boot-imx6ull14x14evk_emmc.imx                               **uboot**

files/zImage名字没变                                                           **zImage**

files/zImage-imx6ul%lite%-%6uldtb%-emmc.dtb为       **dtb**

zImage-imx6ull-14x14-evk-emmc.dtb

files/rootfs_nogpu.tar.bz2      （rootfs）                           **rootfs**

# 13 创建自己的烧写工具

1 确定自己的系统文件命名



2 创建自己的vbs



3 改造ucl2.xml



4 启动测试

uboot可以运行，但是内核没启动

```
Booting from mmc ...
reading imx6ull-14x14-evk.dtb
** Unable to read file imx6ull-14x14-evk.dtb **
Kernel image @ 0x80800000 [ 0x000000 - 0x542be0 ]

```

可以看出，uboot读取的dtb文件名为 imx6ull-14x14-evk.dtb

但是实际上

```
Hit any key to stop autoboot:  0
=> fatls
fatls - list files in a directory (default /)

Usage:
fatls <interface> [<dev[:part]>] [directory]
    - list files from 'dev' on 'interface' in a 'directory'
=> fatls mmc 1:1
  5516256   zimage
    38743   imx6ull-alientek-emmc.dtb

2 file(s), 0 dir(s)

```

实际的dtb文件名为imx6ull-alientek-emmc.dtb，所以修改bootcmd命令

```
=> setenv bootcmd 'fatload mmc 1:1 80800000 zImage;fatload mmc 1:1 83000000 imx6ull-alientek-emmc.dtb;bootz 80800000 - 83000000;'
=> saveenv
Saving Environment to MMC...
Writing to MMC(1)... done

```

还需要设置新的bootargs

```
 setenv bootargs 'console=ttymxc0,115200 root=/dev/mmcblk1p2 rootwait rw'
```

