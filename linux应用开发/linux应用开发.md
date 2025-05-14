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

## 4.4 信号量与条件变量

### **1. 核心用途**

- **信号量 (Semaphore)**
  用于管理对共享资源的访问权限，**控制并发线程/进程的数量**。例如：
  - 限制同时访问某资源的线程数（如数据库连接池）。
  - 实现生产者-消费者模型中的缓冲区容量控制。
- **条件变量 (Condition Variable)**
  用于在**线程间通知特定条件的达成**，通常与互斥锁（Mutex）配合使用。例如：
  - 生产者通知消费者“数据已准备好”。
  - 线程等待某个计算结果完成后再继续执行。

### **2. 内部机制**

- **信号量**
  - 内部维护一个**计数器**，表示可用资源数量。
  - `wait()`（P操作）：若计数器 > 0，减1并继续；否则阻塞线程。
  - `signal()`（V操作）：计数器加1，唤醒一个等待线程。
  - 操作是原子的，无需额外锁保护。
- **条件变量**
  - **没有内部计数器**，依赖外部条件判断。
  - `wait()`：释放关联的互斥锁，阻塞线程直到被唤醒。
  - `signal()`：唤醒一个等待线程（或 `broadcast()` 唤醒所有）。
  - 必须与互斥锁配合使用，以确保条件检查的原子性。

- **信号量无法直接替代条件变量**
  条件变量的 `wait()` 会释放锁并阻塞，确保在等待期间其他线程能修改条件。信号量缺乏直接关联锁的机制，可能导致竞态条件。
- **条件变量无法替代信号量**
  条件变量没有计数器，无法直接控制资源数量。若需限制并发访问数，仍需信号量。

```C
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

#define BUFFER_SIZE 5
int buffer[BUFFER_SIZE];
int count = 0;

// 初始化互斥锁
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
// 初始化条件变量
static pthread_cond_t cond = PTHREAD_COND_INITIALIZER;


// 期望功能是读或者写的一方  一直进行读写操作  直到缓冲读完或者写满  暂时释放锁

/**
 * 向buf中写数据
*/
void * producer(void * arg){
    int item = 1;
    
    // pthread_mutex_lock(&mutex);
    while (1)
    {
        // // 使用共同的变量  使用互斥锁  首先获取锁
        pthread_mutex_lock(&mutex);

        // 如果缓冲区写满  使用条件变量暂停当前线程
        if (count == BUFFER_SIZE)
        {
            // 暂停线程
            pthread_cond_wait(&cond,&mutex);
            
        }
        // 缓冲区没有满
        buffer[count++] = item++;
        printf("白月光发送了一个幸运数字%d\n",buffer[count-1]);
        // 唤醒消费者
        pthread_cond_signal(&cond);
        
        // // 最后释放锁
        pthread_mutex_unlock(&mutex);
    }
    // pthread_mutex_unlock(&mutex);
}

/**
 * 从buf中读数据
*/
void * consumer(void * arg){
    // pthread_mutex_lock(&mutex);
    while (1)
    {
        // 使用共同的变量  使用互斥锁  首先获取锁
        pthread_mutex_lock(&mutex);

        if (count == 0)
        {
            // 缓存中没有消息可读
            // 暂停线程
            pthread_cond_wait(&cond,&mutex);
        }
        
        printf("我收到白月光的幸运数字为%d\n",buffer[--count]);
        // 通知生产者可以继续写
        pthread_cond_signal(&cond);
        // 最后释放锁
        pthread_mutex_unlock(&mutex);
    }
    // pthread_mutex_unlock(&mutex);
}

int main(int argc, char const *argv[])
{
    // 创建两个线程  一个向buf中写 一个从buf中读
    pthread_t producer_thread,consumer_thread;
    // 创建生产者线程
    pthread_create(&producer_thread,NULL,producer,NULL);
    // 创建消费者线程
    pthread_create(&consumer_thread,NULL,consumer,NULL);

    // 主线程需要挂起等待两个线程完成
    pthread_join(producer_thread,NULL);
    pthread_join(consumer_thread,NULL);

    return 0;
}

```

结果出现

```
白月光发送了一个幸运数字27153
白月光发送了一个幸运数字27154
白月光发送了一个幸运数字27155
我收到白月光的幸运数字为27155
我收到白月光的幸运数字为27154
我收到白月光的幸运数字为27153
白月光发送了一个幸运数字27156
白月光发送了一个幸运数字27157
白月光发送了一个幸运数字27158
白月光发送了一个幸运数字27159
白月光发送了一个幸运数字27160
我收到白月光的幸运数字为27160
我收到白月光的幸运数字为27159
我收到白月光的幸运数字为27158
```

**生产者连续生产等问题**

### **1. `pthread_cond_signal` 的唤醒机制**

#### **(1) `pthread_cond_signal` 并不保证立即切换线程**

- 当你调用 `pthread_cond_signal(&cond)` 时，它只是**通知等待 `cond` 的某个线程（如果有）**，但**不会强制当前线程让出 CPU**。

- 被唤醒的消费者线程**不会立即执行**，而是进入**就绪状态**，等待操作系统调度。

- 如果此时生产者线程仍然持有 CPU 时间片，它可能会

  继续生产下一个数据

  ，直到：

  - 它自己调用 `pthread_cond_wait`（缓冲区满时）。
  - 操作系统强制切换线程（时间片用完）。

1. **生产者线程**：
   - 获取锁 `pthread_mutex_lock(&mutex)`。
   - 检查 `count < BUFFER_SIZE`，**不等待**，直接生产数据。
   - 调用 `pthread_cond_signal(&cond)` **尝试唤醒消费者**。
   - **但消费者可能还没进入 `pthread_cond_wait`**（因为它正在处理其他任务，或者还没抢到锁）。
   - 生产者**继续持有锁**，并**再次生产下一个数据**（因为 `count` 仍然 `< BUFFER_SIZE`）。
   - 直到 `count == BUFFER_SIZE`，生产者才会调用 `pthread_cond_wait` 并释放锁。
2. **消费者线程**：
   - 当它终于抢到锁时，可能发现缓冲区已经有多个数据（例如 `count == 3`）。
   - 于是它**连续消费多次**，直到 `count == 0` 才进入 `pthread_cond_wait`。

### 3 信号量

信号量本质上是一个非负整数变量，可以被用来控制对共享资源的访问。它主要用于两种目的：互斥和同步。
（1）互斥（Mutex）：确保多个进程或线程不会同时访问临界区（即访问共享资源的代码区域）。
（2）同步（Synchronization）：协调多个进程或线程的执行顺序，确保它们按照一定的顺序执行。



在当前Linux系统中，有名信号量在临时文件系统中的对应文件位于/dev/shm目录下，创建它们时可以像普通文件一样设置权限模式，限制不同用户的访问权限。

**操作**

信号量主要提供了两个操作：P操作和V操作。
（1）P操作（Proberen，尝试）：也称为等待操作（wait），用于减少信号量的值。如果信号量的值大于0，它就减1并继续执行；如果信号量的值为0，则进程或线程阻塞，直到信号量的值变为非零。
（2）V操作（Verhogen，增加）：也称为信号操作（signal），用于增加信号量的值。如果有其他进程或线程因信号量的值为0而阻塞，这个操作可能会唤醒它们。

**example**

```C
char *shm_value_name = "unnamed_sem_shm_value";
      // 创建信号量 -> 使用共享内存创建
      char *shm_sem_name = "unnamed_sem_shm_sem";
      
      // 创建内存共享对象
      int value_fd = shm_open(shm_value_name, O_CREAT | O_RDWR, 0666);
      int sem_fd = shm_open(shm_sem_name, O_CREAT | O_RDWR, 0666);
      // 调整内存共享对象的大小
      ftruncate(value_fd, sizeof(int));
      ftruncate(sem_fd, sizeof(sem_t));
      // 将内存共享对象映射到共享内存区域
      int *value = mmap(NULL, sizeof(int), PROT_READ | PROT_WRITE, MAP_SHARED, value_fd, 0);
      // 将共享内存的信号量映射到共享内存区域
      sem_t *sem = mmap(NULL, sizeof(sem_t), PROT_READ | PROT_WRITE, MAP_SHARED, sem_fd, 0);
      // 初始化共享变量的值
      *value = 0;
      // 初始化信号量
      sem_init(sem,1,1);

      int pid = fork();

      if (pid > 0) {
            // 父进程
            // 信号量等待
            sem_wait(sem);
            int tmp = *value + 1;
            sleep(1);
            *value = tmp;
            // 信号量唤醒
            sem_post(sem);
            
            // 等待子进程执行完毕
            waitpid(pid, NULL, 0);
            printf("this is father, child finished\n");
            printf("the final value is %d\n", *value);
      } else if (pid == 0) {
        // 子进程
            sem_wait(sem);
            int tmp = *value + 1;
            sleep(1);
            *value = tmp;
            sem_post(sem);
      } else {
            perror("fork");
      }
```

- 定义两个共享内存对象的名称（POSIX 共享内存名字必须像文件名一样）。

- `shm_value_name` 用于共享整数值。

- `shm_sem_name` 用于共享一个信号量。

```C
int value_fd = shm_open(shm_value_name, O_CREAT | O_RDWR, 0666);
int sem_fd = shm_open(shm_sem_name, O_CREAT | O_RDWR, 0666);
```



- 创建或打开两个共享内存对象。

- `O_CREAT | O_RDWR`：创建并以可读写方式打开。

- `0666`：权限设为用户/组/其他均可读写。

```C
ftruncate(value_fd, sizeof(int));
ftruncate(sem_fd, sizeof(sem_t));
```

为这两个共享内存区域指定大小：

- `value_fd` 对应的共享内存为一个整数（通常 4 字节）。
- `sem_fd` 对应的共享内存为一个信号量对象（`sem_t`，一般几十个字节，系统相关）。

```C
*value = 0;
sem_init(sem, 1, 1);
```

`*value = 0;`：初始化共享变量值为 0。

`sem_init(sem, 1, 1);`：

- 初始化这个共享内存中的信号量。
- `1` 表示是用于 **进程间同步**（而不是线程间）。
- `1` 是信号量的初始值，类似于“解锁状态”。

#### 二进制信号量与计数信号量

二进制信号量和计数信号量的划分更多地是从控制效果来说的：二进制信号量起到了互斥锁的作用，当多个进程或线程访问共享资源时，确保同一时刻只有一个进程或线程进入了临界区，起到了“互斥”的作用；而计数信号量起到了“控制顺序”的作用，明确了“谁先执行”、“谁后执行”。很显然，本例是通过信号量控制了线程执行的先后顺序，属于计数信号量。

#### 有名信号量

有名信号量的名称形如/somename，是一个以斜线（/）打头，\0字符结尾的字符串，打头的斜线之后可以有若干字符但不能再出现斜线，长度上限为NAME_MAX-4（即251）。不同的进程可以通过相同的信号量名称访问同一个信号量。

有名信号量通常用于进程间通信，这是因为线程间通信可以有更高效快捷的方式（全局变量等），不必“杀鸡用牛刀”。但要注意的是，正如上文提到的，可以用于进程间通信的方式通常也可以用于线程间通信。

### Conclusion

- 无名信号量和有名信号量均可用于进程间通信，有名信号量是通过唯一的信号量名称在操作系统中唯一标识的。无名信号量用于进程间通信时必须将信号量存储在进程间可以共享的内存区域，作为内存地址直接在进程间共享。而内存区域的共享是通过内存共享对象的唯一名称来实现的。
- 无名信号量和有名信号量都可以作为二进制信号量和计数信号量使用。
- 二进制信号量和计数信号量的区别在于前者起到了互斥锁的作用，而后者起到了控制进程或线程执行顺序的作用。而不仅仅是信号量取值范围的差异。
- 信号量是用来协调进程或线程协同工作的，本身并不用于传输数据。
- 信号量用于跨进程通信时，要格外注意共享资源的创建和释放顺序，避免资源泄露或在不恰当的时机释放资源从而导致未定义行为。

## 4.5 线程池

# 进程与线程

## 1 进程控制块

内核会保存每个进程的一些信息，称为进程控制块（Process Control Block，PCB），方便管理进程，内容如下：
（1）进程编号（PID），每个进程对应的唯一编号，一般为正整数形式。
（2）进程状态信息。
（3）进程切换时需要保存和恢复的一些CPU寄存器，其中关键的有程序计数器（Program Counter）的值，用于记录进程恢复时应执行的指令地址。
（4）内存管理信息，如页表、内存限制、段表等。
（5）当前工作目录（Current Working Directory）。
（6）进程调度信息，包括进程优先级、调度队列指针等。
（7）I/O状态信息，包括分配给进程的I/O设备列表，打开的文件描述符表等，后者包含很多指向file结构体的指针。
（8）同步和通信信息，包括信号量、信号、等用于进程同步和通信机制的信息。
（9）用户id和组id。
在Linux内核中，进程控制块的实现是struct task_struct，上述信息都存储在这个结构体中。

## 2 内存

```C
地址 ↑（高地址）
+---------------------+ 
|     栈 Stack         |  <== 自动变量、函数调用信息等，向低地址增长
|      ↓              |
+---------------------+
|                     |
|     空闲空间（可能为堆）|
|                     |
+---------------------+
|     堆 Heap          |  <== 动态内存 malloc/new，向高地址增长
|      ↑              |
+---------------------+
|     全局/静态变量     |
+---------------------+
|     代码段（Text）    |
地址 ↓（低地址）

```

### 写时复制

```C
#include <stdio.h>
#include <unistd.h>

int main() {
    int a = 42;
    pid_t pid = fork();  // 创建子进程

    if (pid == 0) {  // 子进程
        a = 50;  // 修改 a
        printf("Child: a = %d\n", a);
    } else {  // 父进程
        printf("Parent: a = %d\n", a);
    }

    return 0;
}
```

- 初始时，父子进程的内存是共享的，`a` 的值是 42。

- 子进程修改 `a` 的值时，操作系统会为子进程创建 `a` 的副本，并修改副本的值为 50。

- 父进程的 `a` 值仍然是 42。


## 3 进程切换

进程切换主要在以下几种情况下发生。
（1）时钟中断触发，被中断的进程获得的CPU时间片耗尽，操作系统决定切换进程。
（2）当前进程发生故障，内核夺回CPU控制权，如果故障无法被修复，则内核终止该进程，切换至其它进程。
（3）时钟中断触发，当前进程在等待IO操作，为避免资源浪费，切换至其他进程。
（4）时钟中断触发，高优先级进程处于就绪状态，内核将CPU使用权由当前进程转交给高优先级进程。

**进程的切换需要借助中断或异常，流程如下。假设正在运行的进程A要被切换到进程B。**
（1）CPU暂存栈指针、程序计数器、段选择器和状态寄存器的值。
（2）栈指针由进程A的用户栈切换至它的内核栈，操作系统切换至内核态。
（3）CPU将第一步暂存的寄存器值压入内核栈。
（4）将错误码压入内核栈。
（5）程序计数器指向中断或异常处理程序。
（6）操作系统执行中断或异常处理程序。
（7）在中断或异常处理程序中，调度器会判断是否满足进程切换条件，如果满足则执行以下操作：
① 将进程A所有相关寄存器的值保存至进程A的PCB（Linux底层实现为struct task_struct）。这会包含它的页表基址。
② 有些架构会清除TLB。
③ 将进程B的PCB中记录的页表基址、栈指针等寄存器信息加载（恢复）到对应寄存器。此时栈指针指向进程B的内核栈。进程A回到调度队列。如果进程A是因为CPU时间片耗尽，则处于就绪状态，回到就绪队列。

要注意，打开的文件描述符表等相关资源的切换不需要通过寄存器实现，这些资源存储在struct task_struct结构体中，调度器可以从调度队列获得task_struct，完成资源切换。
（8）执行权限检查，判断当前是否处于内核态。
（9）从进程B的内核栈恢复CS和程序计数器，后者指向B的用户进程代码。
（10）恢复进程B的状态寄存器RFLAGS。
（11）从进程B的内核栈恢复SS和栈指针，后者指向进程B的用户栈，此时切换到用户态。
（12）在用户态下继续进程B的执行，进程切换完成。

# socket

## 1 大端序与小端序

（1）大端字节序（Big-Endian）：高位字节存储在内存的低地址处，低位字节存储在高地址处。这种字节序遵循自然数字的书写习惯，也被称为网络字节序（Network Byte Order）或网络标准字节序，因为它在网络通信中被广泛采用，如IP协议就要求使用大端字节序。
（2）小端字节序（Little-Endian）：低位字节存储在内存的低地址处，高位字节存储在高地址处。这是Intel x86-64架构以及其他一些现代处理器普遍采用的字节序，称为主机字节序（Host Byte Order）。

```bash
feng@os:~/linux/appdev/Linux-application-development/6-socket-test$ cd "/home/feng/linux/appdev/Linux-application-development/6-socket-test" && make -f Makefile num_endianess_convert
gcc -o num_endianess_convert num_endianess_convert.c
./num_endianess_convert
将主机字节序无符号整数0x1F转化为网络字节序0x1F00
将网络字节序无符号整数0x1F00转化为主机字节序0x1F
rm ./num_endianess_convert
```

按字节倒序

## 2 相关函数

```C
    struct sockaddr_in server_addr;
    struct in_addr server_in_addr;

    in_addr_t server_in_addr_t;    
// 不推荐使用  错误返回-1 -> 表示一个正常可用的输出 255.255.255.255
    server_in_addr_t = inet_addr("192.168.6.101");
    printf("inet_addr: 0x%X\n",server_in_addr_t);

    // 推荐使用  出错返回-1  但是传入结构体的数据不是-1
    inet_aton("192.168.6.101",&server_in_addr);
    // 具体只能使用ip协议
    printf("inet_aton: 0x%X\n",server_in_addr.s_addr);

    // 万能方法
    inet_pton(AF_INET,"192.168.6.101",&server_in_addr.s_addr);
    printf("inet_pton: 0x%X\n",server_in_addr.s_addr);
```

## 3 范例

- **服务端**socket链接

```C
    int sockfd,clientfd,temp_result;
    pthread_t pid_read,pid_write;
    struct sockaddr_in server_addr,client_addr;
    // 清空
    memset(&server_addr,0,sizeof(server_addr));
    memset(&client_addr,0,sizeof(client_addr));

    // 填写服务端地址
    server_addr.sin_family = AF_INET;
    // 填写ip地址  0.0.0.0
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    // inet_pton(AF_INET,"0.0.0.0",server_addr.sin_addr.s_addr);
    // 填写端口号
    server_addr.sin_port = htons(6666);

    // 网络编程流程
    // 1. socket
    sockfd = socket(AF_INET,SOCK_STREAM,0);
    handle_error("socket",sockfd);

    // 2. 绑定地址
    temp_result = bind(sockfd,(struct sockaddr *)&server_addr,sizeof(server_addr));
    handle_error("bind",temp_result);

    // 3. 进入监听状态
    temp_result = listen(sockfd,128);
    handle_error("bind",temp_result);

    // 4. 获取客户端的连接
    socklen_t cliaddr_len =  sizeof(client_addr);
    // 返回的文件描述符才是能够和客户端收发消息的文件描述符
    // 如果调用accept之后没有客户端连接  这里会挂起等待
    clientfd = accept(sockfd,(struct sockaddr *)&client_addr,&cliaddr_len);
    handle_error("accept",clientfd);

    printf("与客户端%s %d建立连接 文件描述符是%d\n",inet_ntoa(client_addr.sin_addr),ntohs(client_addr.sin_port),clientfd);
```

# 守护进程与I/O多路复用

## 1 守护进程

守护进程是在操作系统后台运行的一种特殊类型的进程，它独立于前台用户界面，不与任何终端设备直接关联。这些进程通常在系统启动时启动，并持续运行直到系统关闭，或者它们完成其任务并自行终止。守护进程通常用于服务请求、管理系统或执行周期性任务。

## 2 多路复用

IO多路复用（I/O Multiplexing）是Linux中用于处理多个I/O操作的机制，使得单个线程或进程可以同时监视多个文件描述符，以处理多路I/O请求。它主要通过以下系统调用实现：select、poll 和 epoll。

epoll：epoll 是 Linux 特有的、性能优化的 I/O 多路复用机制。它比 select 和 poll 更高效，特别适用于大规模并发连接。epoll 提供了两种工作模式：水平触发（Level-Triggered, LT）和边沿触发（Edge-Triggered, ET）。ET 模式下，epoll 只在状态变化时通知，因此更高效，但也更复杂。

**作用**

（1）节省资源：IO多路复用允许单个进程或线程同时监视多个文件描述符，而不是为每个I/O操作创建一个线程或进程。只需要维护文件描述符，极大地提高了节约了资源，减少了系统开销。
（2）效率高：使用IO多路复用省去了进程或线程上下文切换的开销，提升了处理效率，减少了系统资源（如内存和CPU时间）的消耗，从而提高了应用程序的整体性能和响应速度。
（3）简化编程模型：尽管IO多路复用增加了代码的复杂性，但它简化了高并发程序的设计，使得程序员可以更容易地管理多个I/O操作，而不必处理大量的线程同步问题。

### 2.1 系统调用

在 epoll 的使用中，有两种事件触发模式：边缘触发（Edge Triggered, ET）和水平触发（Level Triggered, LT）。这两种模式决定了 epoll 如何通知应用程序有事件发生。可以类比单片机的边缘触发和电平触发。

水平触发是epoll的默认模式。在这种模式下，只要文件描述符上有未处理的事件，epoll就会不断通知应用程序。

边缘触发模式下，当文件描述符从未就绪状态变为就绪状态时，epoll 会通知应用程序。如果应用程序没有在通知后及时处理事件（例如，读出所有可读的数据），epoll 不会再次通知，除非文件描述符再次从未就绪变为就绪状态。即只在状态变化时通知一次，因而叫边缘触发。
