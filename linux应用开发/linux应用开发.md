# 进程

## 1 父子进程

```c
int fd = open("io.txt", O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd == -1) {
        perror("open");
        exit(EXIT_FAILURE); // exit(1);
    }
    char buffer[1024];
    pid_t pid = fork();
```

```c
ssize_t byte_write = write(fd, buffer, strlen(buffer));
    if (byte_write == -1) {
        perror("write");
        close(fd);
        exit(EXIT_FAILURE); // exit(1);
    }
    printf("write success\n");
    close(fd);
    if(pid == 0){
        printf("child process exit\n");
    }else{
        printf("parent process exit\n");
    }
```

**子进程复制了父进程的文件描述符fd，二者指向的应是同一个底层文件描述（struct file结构体）。我们发现，子进程通过close()释放文件描述符之后，父进程对于相同的文件描述符执行write()操作仍然成功了。这是为什么？**

struct file结构体中有一个属性为**引用计数**，记录的是与当前struct file绑定的文件描述符数量。close()系统调用的作用是将当前进程中的文件描述符和对应的struct file结构体解绑，使得引用计数减一。如果close()执行之后，引用计数变为0，则会释放struct file相关的所有资源。

## 2 exec

exec系列函数可以在同一个进程中跳转执行另外一个程序

```C
char *__path: 需要执行程序的完整路径名
char *const __argv[]: 指向字符串数组的指针 需要传入多个参数
(1) 需要执行的程序命令(同*__path)
(2) 执行程序需要传入的参数
(3) 最后一个参数必须是NULL
char *const __envp[]: 指向字符串数组的指针 需要传入多个环境变量参数
(1) 环境变量参数 固定格式 key=value
(2) 最后一个参数必须是NULL
return: 成功就回不来了 下面的代码都没有意义
失败返回-1
int execve (const char *__path, char *const __argv[], char *const __envp[])
```



## 3 进程间通信

（1）消息队列：允许进程以消息的形式交换数据，这些消息存储在队列中，直到它们被接收。
（2）信号量：主要用于进程间的同步，防止多个进程同时访问相同的资源。
（3）共享内存：允许多个进程访问同一块内存区域，提供了一种非常高效的数据共享方式。

### 3.1 匿名管道

当系统调用或库函数发生错误时，通常会通过设置全局变量errno来指示错误的具体原因。errno是在C语言（及其在Unix、Linux系统下的应用）中用来存储错误号的一个全局变量。每当系统调用或某些库函数遇到错误，无法正常完成操作时，它会将一个错误代码存储到errno中。这个错误代码提供了失败的具体原因，程序可以通过检查errno的值来确定发生了什么错误，并据此进行相应的错误处理。

errno定义在头文件<errno.h>中，引入该文件即可调用全局变量errno。

perror函数用于将errno当前值对应的错误描述以人类可读的形式输出到标准错误输出（stderr）。

**匿名管道是位于内核的一块缓冲区，用于进程间通信。创建匿名管道的系统调用为pipe**

```c
#include <unistd.h>
/**
* 在内核空间创建管道，用于父子进程或者其他相关联的进程之间通过管道进行双向的数据传输。。
*
* pipefd: 用于返回指向管道两端的两个文件描述符。pipefd[0]指向管道的读端。pipefd[1]指向管道的写端。
* return: 成功 0
* 不成功 -1，并且pipefd不会改变
*/
int pipe(int pipefd[2]);
```

管道的读写端通过打开的文件描述符来传递，因此要通信的两个进程必须从它们的公共祖先那里继承管道文件描述符。

也可以父进程fork两次，把文件描述符传给两个子进程，然后两个子进程之间通信，总之需要通过fork传递文件描述符使两个进程都能访问同一管道，它们才能通信。

### 3.2 有名管道（FIFO）

FIFO和Pipe一样，提供了双向进程间通信渠道。但要注意的是，无论是有名管道还是匿名管道，同一条管道只应用于单向通信，否则可能出现通信混乱（进程读到自己发的数据）。