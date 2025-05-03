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

调用open()打开有名管道时，flags设置为**O_WRONLY**则当前进程用于向有名管道写入数据，设置为**O_RDONLY**则当前进程用于从有名管道读取数据。设置为O_RDWR从技术上是可行的，但正如上文提到的，此时管道既读又写很可能导致一个进程读取到自己发送的数据，通信出现混乱。因此，打开有名管道时，flags只应为O_WRONLY或O_RDONLY。

内核为每个被进程打开的FIFO专用文件维护一个管道对象。当进程通过FIFO交换数据时，**内核会在内部传递所有数据，不会将其写入文件系统**。因此，/tmp/myfifo文件大小始终为0



## 4 线程

### 4.1 线程创建

```c
#include <pthread.h>
/**
* 创建一个新线程
*
* pthread_t *thread: 指向线程标识符的指针,线程创建成功时,用于存储新创建线程的线程标识符
* const pthread_attr_t *attr: pthead_attr_t结构体,这个参数可以用来设置线程的属性,如优先级、栈大小等。如果不需要定制线程属性,可以传入 NULL,此时线程将采用默认属性。
* void *(*start_routine)(void *): 一个指向函数的指针,它定义了新线程开始执行时的入口点。这个函数必须接受一个 void * 类型的参数,并返回 void * 类型的结果
* void *arg: start_routine 函数的参数,可以是一个指向任意类型数据的指针
* return: int 线程创建结果
* 成功 0
* 失败 非0
*/
int pthread_create(pthread_t *thread, const pthread_attr_t *attr,void *(*start_routine)(void *), void *arg);
```

### 4.2 线程终止

```C
#include <pthread.h>
/**
* 结束关闭调用该方法的线程，并返回一个内存指针用于存放结果
* void *retval: 要返回给其它线程的数据
*/
void pthread_exit(void *retval);
```

当某个线程调用pthread_exit方法后，该线程会被关闭（相当于return）。线程可以通过retval向其它线程传递信息，retval指向的区域不可以放在线程函数的栈内。其他线程（例如主线程）如果需要获得这个返回值，需要调用pthread_join方法。

```C
#include <pthread.h>
/**
* 等待指定线程结束，获取目标线程的返回值，并在目标线程结束后回收它的资源
*
* pthread_t thread: 指定线程ID
* void **retval: 这是一个可选参数，用于接收线程结束后传递的返回值。如果非空，pthread_join 会在成功时将线程的 exit status 复制到 *retval 所指向的内存位置。如果线程没有显式地通过 pthread_exit 提供返回值，则该参数将被设为 NULL 或忽略
* return: int 成功 0
* 失败 1
*/
int pthread_join(pthread_t thread, void **retval);
```

```C
#include <pthread.h>
/**
* @brief 将线程标记为detached状态。POSIX线程终止后，如果没有调用pthread_detach或pthread_join，其资源会继续占用内存，类似于僵尸进程的未回收状态。默认情况下创建线程后，它处于可join状态，此时可以调用pthread_join等待线程终止并回收资源。但是如果主线程不需要等待线程终止，可以将其标记为detached状态，这意味着线程终止后，其资源会自动被系统回收。
*
* @param thread 线程ID
* @return int 成功返回0，失败返回错误码
*/
int pthread_detach(pthread_t thread);
```

在 POSIX 线程中，默认的取消类型是**延迟取消**（`PTHREAD_CANCEL_DEFERRED`），也就是说：

> **线程不会立即被取消，而是要等它运行到某个“取消点”（如 `sleep()`、`pthread_testcancel()` 等）时，才会真正退出。**

## 4.3 线程同步

当多个线程并发访问和修改同一个共享资源（如全局变量）时，如果没有适当的同步措施，就会遇到线程同步问题。这种情况下，程序最终的结果依赖于线程执行的具体时序，导致了**竞态条件**。

```C
void *add_thread(void *argv)
{
int *p = argv;
(*p)++;
return (void *)0;
}
```

看似简单的 `(*p)++`，实际上在汇编层面是三步操作：

1. 从内存读取 `*p` 的值
2. +1
3. 写回内存

这些操作在多线程下是**非原子的**，多个线程可能同时读取相同值，结果互相覆盖。

**常见的锁机制**
锁主要用于互斥，即在同一时间只允许一个执行单元（进程或线程）访问共享资源。包括上面的互斥锁在内，常见的锁机制共有三种：
（1）互斥锁（Mutex）：保证同一时刻只有一个线程可以执行临界区的代码。
（2）读写锁（Reader/Writer Locks）：允许多个读者同时读共享数据，但写者的访问是互斥的。
（3）自旋锁（Spinlocks）：在获取锁之前，线程在循环中忙等待，适用于锁持有时间非常短的场景，一般是Linux内核使用。

**互斥锁**

```C
#include <pthread.h>
/**
* @brief 获取锁，如果此时锁被占则阻塞
*
* @param mutex 锁
* @return int 获取锁结果
*/
int pthread_mutex_lock(pthread_mutex_t *mutex);
/**
* @brief 非阻塞式获取锁，如果锁此时被占则返回EBUSY
*
* @param mutex 锁
* @return int 获取锁结果
*/
int pthread_mutex_trylock(pthread_mutex_t *mutex);
/**
* @brief 释放锁
*
* @param mutex 锁
* @return int 释放锁结果
*/
int pthread_mutex_unlock(pthread_mutex_t *mutex);
```

**读写锁**

```C
typedef union
{
struct __pthread_rwlock_arch_t __data;
char __size[__SIZEOF_PTHREAD_RWLOCK_T];
long int __align;
} pthread_rwlock_t;
```

```C
/**
* @brief 为rwlock指向的读写锁分配所有需要的资源，并将锁初始化为未锁定状态。读写锁的属性由attr参数指定，如果attr为NULL，则使用默认属性。当锁的属性为默认时，可以通过宏PTHREAD_RWLOCK_INITIALIZER初始化，即
* pthread_rwlock_t rwlock = PTHREAD_RWLOCK_INITIALIZER; 效果和调用当前方法并为attr传入NULL是一样的
*
* @param rwlock 读写锁
* @param attr 读写锁的属性
* @return int 成功则返回0，否则返回错误码
*/
int pthread_rwlock_init(pthread_rwlock_t *restrict rwlock, const pthread_rwlockattr_t *restrict attr);
```

```C
#include <pthread.h>
/**
* @brief 销毁rwlock指向的读写锁对象，并释放它使用的所有资源。当任何线程持有锁的时候销毁锁，或尝试销毁一个未初始化的锁，结果是未定义的。
*
* @param rwlock
* @return int
*/
int pthread_rwlock_destroy(pthread_rwlock_t *rwlock);
```

线程的执行顺序是由操作系统内核调度的，其运行规律并不简单地为“先创建先执行”。
