创建仓库后，在要上传的文件夹里：

```
echo "# linuxDEV" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/Fengzhanpeng156/linuxDEV.git
git push -u origin main
```

将origin改名为github

```
git remote rename origin github
```

配置ssh密钥对

在终端中：

```
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

添加公钥到github：

先查看密钥

```
cat ~/.ssh/id_rsa.pub
```

登录 GitHub，进入 **Settings** -> **SSH and GPG keys**，然后点击 **New SSH key**。

在弹出的界面中，给 SSH 密钥起个名字，并粘贴你刚才复制的公钥内容。

点击 **Add SSH key**。

修改：

```
git remote set-url origin git@github.com:Fengzhanpeng156/linuxDEV.git
```

测试：

```
ssh -T git@github.com
```

```
Hi Fengzhanpeng156! You've successfully authenticated, but GitHub does not provide shell access.
```





# 新建仓库，将别人项目clone到自己仓库

```bash
feng@os:~$ git clone git@github.com:Fengzhanpeng156/bare-metal-programming.git
正克隆到 'bare-metal-programming'...
warning: 您似乎克隆了一个空仓库。
feng@os:~$ cd bare-metal-programming
feng@os:~/bare-metal-programming$ git clone git@github.com:cpq/bare-metal-programming-guide.git
正克隆到 'bare-metal-programming-guide'...
remote: Enumerating objects: 1247, done.
remote: Counting objects: 100% (373/373), done.
remote: Compressing objects: 100% (213/213), done.
remote: Total 1247 (delta 173), reused 172 (delta 160), pack-reused 874 (from 2)
接收对象中: 100% (1247/1247), 4.41 MiB | 510.00 KiB/s, 完成.
处理 delta 中: 100% (739/739), 完成.
feng@os:~/bare-metal-programming$ cd bare-metal-programming-guide/
feng@os:~/bare-metal-programming/bare-metal-programming-guide$ ls
images  LICENSE  README.md  README_tr-TR.md  README_zh-CN.md  steps  templates
feng@os:~/bare-metal-programming/bare-metal-programming-guide$ git remote -v
origin	git@github.com:cpq/bare-metal-programming-guide.git (fetch)
origin	git@github.com:cpq/bare-metal-programming-guide.git (push)
feng@os:~/bare-metal-programming/bare-metal-programming-guide$ git remote set-url origin git@github.com:Fengzhanpeng156/bare-metal-programming.git
feng@os:~/bare-metal-programming/bare-metal-programming-guide$ git remote rename origin github
feng@os:~/bare-metal-programming/bare-metal-programming-guide$ git remote -v
github	git@github.com:Fengzhanpeng156/bare-metal-programming.git (fetch)
github	git@github.com:Fengzhanpeng156/bare-metal-programming.git (push)
```

# 命令行提交

### **添加文件到暂存区**

将修改的文件添加到 git 的暂存区（准备提交）：

```

git add .
```

或者只添加特定文件：

```

git add filename
```

###  **提交修改**

将暂存区的更改提交到本地仓库：

```

git commit -m "Your commit message"
```

### 上传到 GitHub**

将本地仓库的提交上传到 GitHub（推送到远程仓库）：

```

git push origin main
```

如果你的默认分支是 `master`，就用：

```

git push origin master
```
