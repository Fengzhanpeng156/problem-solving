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

