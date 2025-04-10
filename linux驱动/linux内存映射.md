# 地址映射

1 裸机led灯就是操作6ull寄存器

2 linux也可以操作寄存器，linux不能直接对寄存器物理地址直接读写操作，linux会使能MMU

3 在linux里操作的是虚拟地址，所以需要得到物理地址对应的虚拟地址。

4 获得物理地址对应的虚拟地址使用ioremap函数

```
#define ioremap(cookie,size)		__arm_ioremap((cookie), (size), MT_DEVICE)
```

```
extern void __iomem *ioremap(unsigned long physaddr, unsigned long size);
```

第一个参数是物理地址，第二个参数是要转化的字节数量，开始10个地址的转换

```
va = ioremap(0X01010101, 10) 
```

5 卸载驱动：

iounmap(va)



# 2 LED灯字符设备驱动框架搭建

depmod命令



# 3 驱动程序编写

1 配置时钟，IO