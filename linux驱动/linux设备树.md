#  什么是设备树

1 uboot启动内核用到zImage，imx6ull.dtb。bootz 80800000 - 83000000.

2 设备树(Device Tree)，将这个词分开就是“设备”和“树”，描述设备树的文件叫做DTS(Device Tree Source)，这个DTS 文件采用树形结构描述板级设备，也就是开发板上的设备信息，比如CPU 数量、 内存基地址、IIC 接口上接了哪些设备、SPI 接口上接了哪些设备等等

3 在单片机驱动里面各种属性都是在.c文件直接写死，编译进内核。板级信息都写到c里面，导致linux臃肿.因此，将板子信息做成独立格式，扩展名为dts。

# 设备树在系统中的体现

系统启动以后可以在根文件系统里看到设备树节点信息，

在/proc/device-tree/目录下存放着设备树信息。

应该是个软连接

```bash
/ # cd /proc/device-tree/
/sys/firmware/devicetree/base # ls
#address-cells                 memory
#size-cells                    model
aliases                        name
backlight                      pxp_v4l2
chosen                         regulators
clocks                         reserved-memory
compatible                     soc
cpus                           sound
interrupt-controller@00a01000  spi4
```

不同节点都是文件夹

```bash
/sys/firmware/devicetree/base # cd soc/
/sys/firmware/devicetree/base/soc # ls
#address-cells      compatible          ranges
#size-cells         dma-apbh@01804000   sram@00900000
aips-bus@02000000   gpmi-nand@01806000  sram@00904000
aips-bus@02100000   interrupt-parent    sram@00905000
aips-bus@02200000   name
busfreq             pmu

```

描述了内部外设信息



```bash
/sys/firmware/devicetree/base/soc # cd aips-bus@02000000/
/sys/firmware/devicetree/base/soc/aips-bus@02000000 # ls
#address-cells       gpio@020ac000        pwm@020fc000
#size-cells          gpt@02098000         ranges
anatop@020c8000      gpt@020e8000         reg
can@02090000         iomuxc-gpr@020e4000  sdma@020ec000
can@02094000         iomuxc@020e0000      snvs@020b0000
ccm@020c4000         kpp@020b8000         snvs@020cc000
compatible           mqs                  spba-bus@02000000
epit@020d0000        name                 src@020d8000
epit@020d4000        pwm@02080000         tempmon
ethernet@020b4000    pwm@02084000         tsc@02040000
gpc@020dc000         pwm@02088000         usbphy@020c9000
gpio@0209c000        pwm@0208c000         usbphy@020ca000
gpio@020a0000        pwm@020f0000         wdog@020bc000
gpio@020a4000        pwm@020f4000         wdog@020c0000
gpio@020a8000        pwm@020f8000
```

属性信息

```bash
/sys/firmware/devicetree/base/soc/aips-bus@02100000 # cd i2c@021a0000/
/sys/firmware/devicetree/base/soc/aips-bus@02100000/i2c@021a0000 # ls
#address-cells   compatible       name             status
#size-cells      fxls8471@1e      pinctrl-0
clock-frequency  interrupts       pinctrl-names
clocks           mag3110@0e       reg
```

内核启动会解析设备树，然后在/proc/device-tree/目录下呈现出来

# 特殊节点

1 aliases别名

2 chosen

将uboot里面bootargs的环境变量值传递给linux内核组为 命令行参数

chosen节点中包含bootargs属性，属性值与ubootargs一致

经过分析判断，uboot拥有bootargs环境变量和dtb

最终发现，uboot的fdt_chosen函数中会查找chosen节点，并且在里面添加bootargs属性，属性值为bootargs变量值。



# 特殊的属性

1 compatible属性

兼容性

值是字符串

节点里的reg属性数量由父节点决定

**根节点下面的compatible属性**

内核启动会检查支不支持此平台

不适用设备树时候，通过使用machine id判断是否支持

设备树使用

```
DT_MACHINE_START(IMX6UL, "Freescale i.MX6 Ultralite (Device Tree)")
	.map_io		= imx6ul_map_io,
	.init_irq	= imx6ul_init_irq,
	.init_machine	= imx6ul_init_machine,
	.init_late	= imx6ul_init_late,
	.dt_compat	= imx6ul_dt_compat,
MACHINE_END
```

# linux内核的OF操作函数

1 驱动如何获取设备树节点信息

在驱动中使用OF函数获取设备树属性内容

/include/linux/of.h

2 驱动要想获取到设备树节点内容，首先要找到节点

**遇到问题**

```
feng@os:~/linux/IMX6ULL/linux_drivers/4_dtsof$ make
make -C /home/feng/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga M=/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof modules 
make[1]: 进入目录“/home/feng/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga”
  CC [M]  /home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.o
/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.c: 在函数‘dtsof_init’中:
/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.c:82:2: 错误： 隐式声明函数‘kmalloc’ [-Werror=implicit-function-declaration]
  brival = kmalloc(elemsize * sizeof(u32), GFP_KERNEL);
  ^
/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.c:82:9: 警告： assignment makes pointer from integer without a cast
  brival = kmalloc(elemsize * sizeof(u32), GFP_KERNEL);
         ^
/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.c:98:2: 错误： 隐式声明函数‘kfree’ [-Werror=implicit-function-declaration]
  kfree(brival);
  ^
cc1：有些警告被当作是错误
make[2]: *** [scripts/Makefile.build:265：/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.o] 错误 1
make[1]: *** [Makefile:1385：_module_/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof] 错误 2
make[1]: 离开目录“/home/feng/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga”
```

**解决**

```
在你的 dtsof.c 中添加头文件：

#include <linux/slab.h>
这个头文件定义了动态内存管理函数，比如 kmalloc 和 kfree。
```

**问题**

```
feng@os:~/linux/IMX6ULL/linux_drivers/4_dtsof$ make
make -C /home/feng/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga M=/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof modules 
make[1]: 进入目录“/home/feng/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga”
  CC [M]  /home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.o
/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.c: 在函数‘dtsof_init’中:
/home/feng/linux/IMX6ULL/linux_drivers/4_dtsof/dtsof.c:13:6: 警告： 未使用的变量‘ret’ [-Wunused-variable]
  int ret = 0;
      ^
  Building modules, stage 2.
  MODPOST 1 modules
FATAL: section header offset=11259024840327220 in file 'vmlinux' is bigger than filesize=14007300
make[2]: *** [scripts/Makefile.modpost:90：__modpost] 错误 1
make[1]: *** [Makefile:1389：modules] 错误 2
make[1]: 离开目录“/home/feng/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga”
make: *** [Makefile:11：kernel_modules] 错误 2
```

**解决**

```FATAL: section header offset=11259024840327220 in file 'vmlinux' is bigger than filesize=14007300```这个报错来自于 `modpost` 阶段，也就是说内核模块已经编译好了，但在生成 `.mod.c` 等模块描述信息时出错，根本原因是**你的内核编译目录下的 `vmlinux` 文件可能已损坏、缺失或格式不正确**。

```
重新编译内核
```

