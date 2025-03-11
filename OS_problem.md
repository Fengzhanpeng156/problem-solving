**问题描述：**
Failed to connect to github.com port 443: Connection timed out

**解决：**
设置代理
git config --global https.proxy 172.18.176.1:7890
git config --global http.proxy 172.18.176.1:7890