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
