# 字符设备驱动开发

字符设备是Linux 驱动中最基本的一类设备驱动，字符设备就是一个一个字节，按照字节
流进行读写操作的设备，读写数据是分先后顺序的。比如我们最常见的点灯、按键、IIC、SPI，
LCD 等等都是字符设备，这些设备的驱动就叫做字符设备驱动。



驱动就是获取外设或者传感器数据，控制外设。数据提交给应用程序。

linux驱动既要编写驱动，也要编写简单测试应用程序。单片机驱动和应用是杂糅一起的。



# 1 字符设备驱动框架

字符设备驱动的编写主要就是驱动对应的 open,close,read

其实就是file_operations结构体成员变量的实现



# 2 驱动模块加载与卸载

linux驱动程序可以编译到kernel里，也就是zImage，也可以编译为模块.ko格式。测试时只需加载.ko模块。



**编写驱动时候注意事项**

编译驱动时候需要用到linux内核源码，因此要解压缩linux内核源码，编译linux内核源码。得到zImage和dtb。需要使用编译得到的zImage和dtb启动项目

```makefile
KERNELDIR := /home/feng/linux/IMX6ULL/linux/linux-imx-rel_imx_4.1.15_2.1.0_ga
CURRENT_PATH := $(shell pwd)
CROSS_COMPILE := arm-linux-gnueabihf-
ARCH := arm

obj-m := chrdevbase.o

build: kernel_modules

kernel_modules:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules 

clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) clean
```

从sd卡启动，sd卡烧写了uboot。uboot通过tftp从ubuntu获取zImage和dtb，rootfs也是通过nfs挂载

设置bootcmd和bootargs

```
bootargs=console=ttymxc0,115200 root=/dev/nfs nfsroot=192.168.10.100:/home/feng/linux/nfs/rootfs,proto=tcp rw ip=192.168.10.50:192.168.10.100:192.168.10.1:255.255.255.0::eth0:off
bootcmd=tftp 80800000 zImage;tftp 83000000 imx6ull-alientek-emmc.dtb;bootz 80800000 - 83000000;

```



将编译出来的.ko文件放到根文件系统里。加载驱动会用到加载命令：

insmod，modprobe。

移除驱动使用rmmod。

对于新的模块，使用modprobe加载的时候，需要先调用depmod

驱动模块加载成功以后使用lsmod查看

卸载模块使用rmmod chedevbase.ko



# 3 字符设备注册与注销

1 我们需要向系统注册一个字符设备，使用函数register_chrdev。

2 卸载驱动时候需要注销掉前面注册字符设备unregister_chrdev。



# 4 设备号

1 linux使用dev_t的数据类型表示设备号， dev_t定义在文件 include/linux/types.h

```
typedef __kernel_dev_t		dev_t;
```

```
typedef __u32 __kernel_dev_t;
```

```
typedef unsigned int __u32;
```

2 主设备号前12位，次设备号低20位

3  设备号操作函数或宏

MAJOR（dev_t），MINOR(dev_t)

也可以使用主设备号和次设备号构成dev_t，MKDEV(ma,mi)

# 5 file_operations具体实现

```c
struct file_operations {
	struct module *owner;
	loff_t (*llseek) (struct file *, loff_t, int);
	ssize_t (*read) (struct file *, char __user *, size_t, loff_t *);
	ssize_t (*write) (struct file *, const char __user *, size_t, loff_t *);
	ssize_t (*read_iter) (struct kiocb *, struct iov_iter *);
	ssize_t (*write_iter) (struct kiocb *, struct iov_iter *);
	int (*iterate) (struct file *, struct dir_context *);
	unsigned int (*poll) (struct file *, struct poll_table_struct *);
	long (*unlocked_ioctl) (struct file *, unsigned int, unsigned long);
	long (*compat_ioctl) (struct file *, unsigned int, unsigned long);
	int (*mmap) (struct file *, struct vm_area_struct *);
	int (*mremap)(struct file *, struct vm_area_struct *);
	int (*open) (struct inode *, struct file *);
	int (*flush) (struct file *, fl_owner_t id);
	int (*release) (struct inode *, struct file *);
	int (*fsync) (struct file *, loff_t, loff_t, int datasync);
	int (*aio_fsync) (struct kiocb *, int datasync);
	int (*fasync) (int, struct file *, int);
	int (*lock) (struct file *, int, struct file_lock *);
	ssize_t (*sendpage) (struct file *, struct page *, int, size_t, loff_t *, int);
	unsigned long (*get_unmapped_area)(struct file *, unsigned long, unsigned long, unsigned long, unsigned long);
	int (*check_flags)(int);
	int (*flock) (struct file *, int, struct file_lock *);
	ssize_t (*splice_write)(struct pipe_inode_info *, struct file *, loff_t *, size_t, unsigned int);
	ssize_t (*splice_read)(struct file *, loff_t *, struct pipe_inode_info *, size_t, unsigned int);
	int (*setlease)(struct file *, long, struct file_lock **, void **);
	long (*fallocate)(struct file *file, int mode, loff_t offset,
			  loff_t len);
	void (*show_fdinfo)(struct seq_file *m, struct file *f);
#ifndef CONFIG_MMU
	unsigned (*mmap_capabilities)(struct file *);
#endif
};
```

# 6 字符设备驱动框架搭建



# 7 应用程序编写

linux下一切皆文件，首先open



# 8 测试

1 加载驱动```modprobe chrdevbase.ko```

2 进入dev查看设备文件

创建设备节点

```
mknod /dev/chrdevbase c 200 0

```

3 测试

```
./chrdevbaseAPP /dev/chrdevbase
```



# 9 chedevbase虚拟设备驱动对的编写

要求：应用程序可以对驱动读写操作，读就是从驱动里面读字符，写就是应用向驱动写字符

1 chrdevbase_read驱动函数编写

驱动给应用传递数据时候要用```copy_to_user```函数



