# WSL2中的ubuntu20.04

**问题描述：**
Failed to connect to github.com port 443: Connection timed out

**解决：**
设置代理
git config --global https.proxy 172.18.176.1:7890
git config --global http.proxy 172.18.176.1:7890



# 在vm虚拟机的ubuntu20.04中

**问题描述**

在终端中git clone报错

GnuTLS recv error (-110): The TLS connection was non-properly terminated

**解决**

因为之前clash开启了局域网共享，所以在ubuntu中手动设置了ipv4，只需要

git config --global https.proxy ~~172.18.176.1:7890~~
git config --global http.proxy ~~172.18.176.1:7890~~

IP地址与端口改为ubuntu手动设置就行。