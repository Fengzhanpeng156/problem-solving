# Work 1 System call tracing

首先根据提示定义`trace`系统调用，并修复编译错误。

首先看一下```*user/trace.c*```的内容

```c
if (trace(atoi(argv[1])) < 0) {
    fprintf(2, "%s: trace failed\n", argv[0]);
    exit(1);
}
for(i = 2; i < argc && i < MAXARG; i++){
    nargv[i-2] = argv[i];
}
exec(nargv[0], nargv);
```

它首先调用`trace(int)`，然后将命令行中的参数`argv`复制到`nargv`中，同时删去前两个参数，例如

```C
argv  = trace 32 grep hello README
nargv = grep hello README
```

## 用户态修改

user/user.h

```C
// system calls
int fork(void);
int exit(int) __attribute__((noreturn));
int wait(int*);
int pipe(int*);
int write(int, const void*, int);
int read(int, void*, int);
int close(int);
int kill(int);
int exec(char*, char**);
int open(const char*, int);
int mknod(const char*, short, short);
int unlink(const char*);
int fstat(int fd, struct stat*);
int link(const char*, const char*);
int mkdir(const char*);
int chdir(const char*);
int dup(int);
int getpid(void);
char* sbrk(int);
int sleep(int);
int uptime(void);
int trace(int); ///用户态系统调用入口函数
```

/user/usys.pl

```perl
entry("link");
entry("mkdir");
entry("chdir");
entry("dup");
entry("getpid");
entry("sbrk");
entry("sleep");
entry("uptime");
entry("trace");  //here
```

这个脚本在运行后会生成 usys.S 汇编文件，里面定义了每个 system call 的用户态跳板函数

```assembly
 trace:		# 定义用户态跳板函数
 li a7, SYS_trace	# 将系统调用 id 存入 a7 寄存器
 ecall				# ecall，调用 system call ，跳到内核态的统一系统调用处理函数 syscall()  (syscall.c)
 ret
```

Makefile

```makefile
UPROGS=\
	$U/_cat\
	$U/_echo\
	$U/_forktest\
	$U/_grep\
	$U/_init\
	$U/_kill\
	$U/_ln\
	$U/_ls\
	$U/_mkdir\
	$U/_rm\
	$U/_sh\
	$U/_stressfs\
	$U/_usertests\
	$U/_grind\
	$U/_wc\
	$U/_zombie\
	$U/_trace\
```

## 内核态修改

kernel/syscall.h

```c
 #define SYS_trace  22 // here!!!!!
```

kernel/syscall.c

```c
 extern uint64 sys_trace(void);   // HERE
static uint64 (*syscalls[])(void) = {
 [SYS_fork]    sys_fork,
 [SYS_exit]    sys_exit,
 [SYS_wait]    sys_wait,
 [SYS_pipe]    sys_pipe,
 [SYS_read]    sys_read,
 [SYS_kill]    sys_kill,
 [SYS_exec]    sys_exec,
 [SYS_fstat]   sys_fstat,
 [SYS_chdir]   sys_chdir,
 [SYS_dup]     sys_dup,
 [SYS_getpid]  sys_getpid,
 [SYS_sbrk]    sys_sbrk,
 [SYS_sleep]   sys_sleep,
 [SYS_uptime]  sys_uptime,
 [SYS_open]    sys_open,
 [SYS_write]   sys_write,
 [SYS_mknod]   sys_mknod,
 [SYS_unlink]  sys_unlink,
 [SYS_link]    sys_link,
 [SYS_mkdir]   sys_mkdir,
 [SYS_close]   sys_close,
 [SYS_trace]   sys_trace,  // AND HERE
```

kernel/proc.h

```c
struct proc {
  struct spinlock lock;

  // p->lock must be held when using these:
  enum procstate state;        // Process state
  struct proc *parent;         // Parent process
  void *chan;                  // If non-zero, sleeping on chan
  int killed;                  // If non-zero, have been killed
  int xstate;                  // Exit status to be returned to parent's wait
  int pid;                     // Process ID

  // these are private to the process, so p->lock need not be held.
  uint64 kstack;               // Virtual address of kernel stack
  uint64 sz;                   // Size of process memory (bytes)
  pagetable_t pagetable;       // User page table
  struct trapframe *trapframe; // data page for trampoline.S
  struct context context;      // swtch() here to run process
  struct file *ofile[NOFILE];  // Open files
  struct inode *cwd;           // Current directory
  char name[16];               // Process name (debugging)
  uint64 syscall_trace;         //Mask for syscall tracing (新添加的用于标识追踪哪些 system call 的 mask)
};
```

kernel/proc.c

```c
allocproc(void)
{
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->state == UNUSED) {
      goto found;
    } else {
      release(&p->lock);
    }
  }
  return 0;

found:
  p->pid = allocpid();

  // Allocate a trapframe page.
  if((p->trapframe = (struct trapframe *)kalloc()) == 0){
    release(&p->lock);
    return 0;
  }

  // An empty user page table.
  p->pagetable = proc_pagetable(p);
  if(p->pagetable == 0){
    freeproc(p);
    release(&p->lock);
    return 0;
  }

  // Set up new context to start executing at forkret,
  // which returns to user space.
  memset(&p->context, 0, sizeof(p->context));
  p->context.ra = (uint64)forkret;
  p->context.sp = p->kstack + PGSIZE;

  p->syscall_trace = 0; //初始化系统调用掩码

  return p;
}
```



修改 fork 函数，使得子进程可以继承父进程的 syscall_trace mask：

```c

int
fork(void)
{
  int i, pid;
  struct proc *np;
  struct proc *p = myproc();

  // Allocate process.
  if((np = allocproc()) == 0){
    return -1;
  }

  // Copy user memory from parent to child.
  if(uvmcopy(p->pagetable, np->pagetable, p->sz) < 0){
    freeproc(np);
    release(&np->lock);
    return -1;
  }
  np->sz = p->sz;

  np->parent = p;

  // copy saved user registers.
  *(np->trapframe) = *(p->trapframe);

  // Cause fork to return 0 in the child.
  np->trapframe->a0 = 0;

  // increment reference counts on open file descriptors.
  for(i = 0; i < NOFILE; i++)
    if(p->ofile[i])
      np->ofile[i] = filedup(p->ofile[i]);
  np->cwd = idup(p->cwd);

  safestrcpy(np->name, p->name, sizeof(p->name));

  np -> syscall_trace = p ->syscall_trace;// 子进程复制父进程系统调用掩码

  pid = np->pid;

  np->state = RUNNABLE;

  release(&np->lock);

  


  return pid;
}
```

kernel/sysproc.c

```c
 // kernel/sysproc.c
 // 这里着重理解如何添加系统调用，对于这个调用的具体代码细节在后面的部分分析
 uint64
 sys_trace(void)
 {
 int mask;

 if(argint(0, &mask) < 0)
     return -1;
	
 myproc()->syscall_trace = mask;
 return 0;
 }
```

根据上方提到的系统调用的全流程，可以知道，所有的系统调用到达内核态后，都会进入到 syscall() 这个函数进行处理，所以要跟踪所有的内核函数，只需要在 syscall() 函数里埋点就行了

```c
// kernel/syscall.c
void
syscall(void)
{
  int num;
  struct proc *p = myproc();

  num = p->trapframe->a7;
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) { // 如果系统调用编号有效
    p->trapframe->a0 = syscalls[num](); // 通过系统调用编号，获取系统调用处理函数的指针，调用并将返回值存到用户进程的 a0 寄存器中
	// 如果当前进程设置了对该编号系统调用的 trace，则打出 pid、系统调用名称和返回值。
    if((p->syscall_trace >> num) & 1) {
      printf("%d: syscall %s -> %d\n",p->pid, syscall_names[num], p->trapframe->a0); // syscall_names[num]: 从 syscall 编号到 syscall 名的映射表
    }
  } else {
    printf("%d %s: unknown sys call %d\n",
            p->pid, p->name, num);
    p->trapframe->a0 = -1;
  }
}
```

上面打出日志的过程还需要知道系统调用的名称字符串，在这里定义一个字符串数组进行映射：

```c
 // kernel/syscall.c
const char *syscall_names[] = {
[SYS_fork]    "fork",
[SYS_exit]    "exit",
[SYS_wait]    "wait",
[SYS_pipe]    "pipe",
[SYS_read]    "read",
[SYS_kill]    "kill",
[SYS_exec]    "exec",
[SYS_fstat]   "fstat",
[SYS_chdir]   "chdir",
[SYS_dup]     "dup",
[SYS_getpid]  "getpid",
[SYS_sbrk]    "sbrk",
[SYS_sleep]   "sleep",
[SYS_uptime]  "uptime",
[SYS_open]    "open",
[SYS_write]   "write",
[SYS_mknod]   "mknod",
[SYS_unlink]  "unlink",
[SYS_link]    "link",
[SYS_mkdir]   "mkdir",
[SYS_close]   "close",
[SYS_trace]   "trace",
};
```