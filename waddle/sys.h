#pragma once

#define inline __inline
#define asm __asm__

#define NULL       ((void *)0)
#define PATH_MAX   4096

#ifdef __x86_64__
typedef   signed long ssize_t;
typedef unsigned long  size_t;
typedef   signed char      s8;
typedef   signed short     s16;
typedef   signed int       s32;
typedef   signed long long s64;
typedef unsigned char      u8;
typedef unsigned short     u16;
typedef unsigned int       u32;
typedef unsigned long long u64;
# define SIZE_MAX (~(size_t)0)
#else
# error "unsupported architecture"
#endif

typedef u32 socklen_t;
typedef u16 sa_family_t;
typedef int pid_t;
typedef int uid_t;
typedef int gid_t;
typedef u64 time_t;
typedef u64 time64_t;
typedef s32 suseconds_t;
typedef u64 off_t;

struct timeval {
	time64_t     tv_sec;
	suseconds_t  tv_usec;
};

struct rusage {
	struct timeval  ru_utime;
	struct timeval  ru_stime;
	long            ru_maxrss;
	long            ru_ixrss;
	long            ru_idrss;
	long            ru_isrss;
	long            ru_minflt;
	long            ru_majflt;
	long            ru_nswap;
	long            ru_inblock;
	long            ru_outblock;
	long            ru_msgsnd;
	long            ru_msgrcv;
	long            ru_nsignals;
	long            ru_nvcsw;
	long            ru_nivcsw;
};

struct iovec {
	void     *iov_base;
	size_t    iov_len;
};

struct msghdr {
	void          *msg_name;
	socklen_t      msg_namelen;
	struct iovec  *msg_iov;
	size_t         msg_iovlen;
	void          *msg_control;
	size_t         msg_controllen;
	int            msg_flags;
};

struct sockaddr {
	sa_family_t  sa_family;
};

struct sockaddr_nl {
	sa_family_t  nl_family;
	u16          nl_pad;
	u32          nl_pid;
	u32          nl_groups;
};

/* https://docs.kernel.org/userspace-api/netlink/intro.html */
struct nlmsghdr {
      u32   nlmsg_len;      /* Length of message including headers */
      u16   nlmsg_type;     /* Generic Netlink Family (subsystem) ID */
      u16   nlmsg_flags;    /* Flags - request or dump */
      u32   nlmsg_seq;      /* Sequence number */
      u32   nlmsg_pid;      /* Port ID, set to 0 */
};

struct genlmsghdr {
      u8    cmd;            /* Command, as defined by the Family */
      u8    version;        /* Irrelevant, set to 1 */
      u16   reserved;       /* Reserved, set to 0 */
};

struct nlattr {
	u16  nla_len;
	u16  nla_type;
};

struct ifinfomsg {
	sa_family_t  ifi_family; /* AF_UNSPEC */
	u16          ifi_type;   /* Device type */
	s32          ifi_index;  /* Interface index */
	u32          ifi_flags;  /* Device flags  */
	u32          ifi_change; /* change mask */
};

struct ifaddrmsg {
	u8   ifa_family;
	u8   ifa_prefixlen;
	u8   ifa_flags;
	u8   ifa_scope;
	u32  ifa_index;
};

#define AF_UNSPEC          0
#define AF_UNIX            1
#define AF_INET            2
#define AF_AX25            3
#define AF_IPX             4
#define AF_APPLETALK       5
#define AF_NETROM          6
#define AF_BRIDGE          7
#define AF_ATMPVC          8
#define AF_X25             9
#define AF_INET6          10
#define AF_ROSE           11
#define AF_DECnet         12
#define AF_NETBEUI        13
#define AF_SECURITY       14
#define AF_KEY            15
#define AF_NETLINK        16
#define AF_PACKET         17
#define AF_ASH            18
#define AF_ECONET         19
#define AF_ATMSVC         20
#define AF_RDS            21
#define AF_SNA            22
#define AF_IRDA           23
#define AF_PPPOX          24
#define AF_WANPIPE        25
#define AF_LLC            26
#define AF_IB             27
#define AF_MPLS           28
#define AF_CAN            29
#define AF_TIPC           30
#define AF_BLUETOOTH      31
#define AF_IUCV           32
#define AF_RXRPC          33
#define AF_ISDN           34
#define AF_PHONET         35
#define AF_IEEE802154     36
#define AF_CAIF           37
#define AF_ALG            38
#define AF_NFC            39
#define AF_VSOCK          40
#define AF_KCM            41
#define AF_OIPCRTR        42
#define AF_SMC            43
#define AF_XDP            44
#define AF_MCTP           45

#define NETLINK_ROUTE      0
#define NETLINK_GENERIC   16

#define NETLINK_EXT_ACK         11
#define NETLINK_GET_STRICT_CHK  12

#define SOCK_DGRAM               1
#define SOCK_STREAM              2
#define SOCK_RAW                 3
#define SOCK_SEQPACKET           5
#define SOCK_CLOEXEC      02000000

#define SOL_SOCKET               1
#define SOL_NETLINK            270

#define SO_SNDBUF                7
#define SO_RCVBUF                8
#define SO_ACCEPTCONN           30

#define ARPHRD_NETROM     0

#define RTM_NEWLINK   16
#define RTM_DELLINK   17
#define RTM_GETLINK   18
#define RTM_SETLINK   19
#define RTM_NEWADDR   20
#define RTM_DELADDR   21
#define RTM_GETADDR   22
#define RTM_NEWROUTE  23
#define RTM_DELROUTE  24
#define RTM_GETROUTE  25

#define NLMSG_NOOP               1
#define NLMSG_ERROR              2
#define NLMSG_DONE               3
#define NLMSG_OVERRUN            4

#define NLM_F_REQUEST         0x01
#define NLM_F_MULTI           0x02
#define NLM_F_ACK             0x04
#define NLM_F_ECHO            0x08
#define NLM_F_DUMP_INTR       0x10
#define NLM_F_DUMP_FILTERED   0x20
#define NLM_F_ROOT           0x100
#define NLM_F_MATCH          0x200
#define NLM_F_DUMP           (NLM_F_ROOT | NLM_F_MATCH)
#define NLM_F_ATOMIC         0x400
#define NLM_F_REPLACE        0x100
#define NLM_F_EXCL           0x200
#define NLM_F_CREATE         0x400
#define NLM_F_APPEND         0x800
#define NLM_F_NONREC         0x100
#define NLM_F_BULK           0x200
#define NLM_F_CAPPED         0x100

#define IFA_ADDRESS           1
#define IFA_LOCAL             2
#define IFA_LABEL             3
#define IFA_BROADCAST         4
#define IFA_ANYCAST           5
#define IFA_CACHEINFO         6
#define IFA_MULTICAST         7
#define IFA_FLAGS             8
#define IFA_RT_PRIORITY       9
#define IFA_TARGET_NETNSID   10
#define IFA_PROTO            11

#define IFF_UP                1

#define IFLA_ADDRESS          1
#define IFLA_BROADCAST        2
#define IFLA_IFNAME           3
#define IFLA_MTU              4
#define IFLA_LINK             5
#define IFLA_QDISC            6
#define IFLA_STATS            7
#define IFLA_COST             8
#define IFLA_PRIORITY         9
#define IFLA_MASTER          10
#define IFLA_WIRELESS        11
#define IFLA_PROTINFO        12
#define IFLA_TXQLEN          13
#define IFLA_MAP             14
#define IFLA_WEIGHT          15
#define IFLA_OPERSTATE       16
#define IFLA_LINKMODE        17
#define IFLA_LINKINFO        18
#define IFLA_NET_NS_PID      19
#define IFLA_IFALIAS         20
#define IFLA_NUM_VF          21
#define IFLA_VFINFO_LIST     22
#define IFLA_STATS64         23
#define IFLA_VF_PORTS        24
#define IFLA_PORT_SELF       25
#define IFLA_AF_SPEC         26
#define IFLA_GROUP           27
#define IFLA_NET_NS_FD       28

#define IFLA_INFO_KIND        1
#define IFLA_INFO_DATA        2
#define IFLA_INFO_XSTATS      3
#define IFLA_INFO_SLAVE_KIND  4
#define IFLA_INFO_SLAVE_DATA  5

#define IFNAMSIZ             15

#define SIOCGIFINDEX     0x8933

#define RT_SCOPE_UNIVERSE     0

#define PR_SET_PDEATHSIG      1
#define PR_SET_NAME          15

#define SIGKILL               9

#ifdef __x86_64__
# define SYS_WRITE          1
# define SYS_OPEN           2
# define SYS_CLOSE          3
# define SYS_IOCTL         16
# define SYS_GETPID        39
# define SYS_SENDFILE      40
# define SYS_SOCKET        41
# define SYS_SENDMSG       46
# define SYS_RECVMSG       47
# define SYS_BIND          49
# define SYS_GETSOCKNAME   51
# define SYS_SETSOCKOPT    54
# define SYS_GETSOCKOPT    55
# define SYS_CLONE         56
# define SYS_FORK          57
# define SYS_EXECVE        59
# define SYS_EXIT          60
# define SYS_WAIT4         61
# define SYS_CHDIR         80
# define SYS_MKDIR         83
# define SYS_GETUID       102
# define SYS_GETGID       104
# define SYS_GETPPID      110
# define SYS_GETPGRP      111
# define SYS_SETSID       112
# define SYS_PIVOT_ROOT   155
# define SYS_PRCTL        157
# define SYS_CHROOT       161
# define SYS_MOUNT        165
# define SYS_UMOUNT2      166
# define SYS_TIME         201
# define SYS_UNSHARE      272
# define SYS_GETRANDOM    318
# define SYS_FSOPEN       430
# define SYS_FSCONFIG     431
# define SYS_FSMOUNT      432
static inline size_t syscall0(size_t id) {
	size_t ret;
	asm volatile ("syscall" : "=a"(ret) : "a"(id) : "rcx", "r11", "memory");
	return ret;
}
static inline size_t syscall1(size_t id, size_t a0) {
	size_t ret;
	asm volatile ("syscall" : "=a"(ret) : "a"(id), "D"(a0) : "rcx", "r11", "memory");
	return ret;
}
static inline size_t syscall2(size_t id, size_t a0, size_t a1) {
	size_t ret;
	asm volatile ("syscall" : "=a"(ret) : "a"(id), "D"(a0), "S"(a1) : "rcx", "r11", "memory");
	return ret;
}
static inline size_t syscall3(size_t id, size_t a0, size_t a1, size_t a2) {
	size_t ret;
	asm volatile ("syscall" : "=a"(ret) : "a"(id), "D"(a0), "S"(a1), "d"(a2) : "rcx", "r11", "memory");
	return ret;
}
static inline size_t syscall4(size_t id, size_t a0, size_t a1, size_t a2, size_t a3) {
	size_t ret;
	register size_t r10 asm("r10") = a3;
	asm volatile ("syscall" : "=a"(ret) : "a"(id), "D"(a0), "S"(a1), "d"(a2), "r"(r10) : "rcx", "r11", "memory");
	return ret;
}
static inline size_t syscall5(size_t id, size_t a0, size_t a1, size_t a2, size_t a3, size_t a4) {
	size_t ret;
	register size_t r10 asm("r10") = a3;
	register size_t r8  asm("r8" ) = a4;
	asm volatile ("syscall" : "=a"(ret) : "a"(id), "D"(a0), "S"(a1), "d"(a2), "r"(r10), "r"(r8) : "rcx", "r11", "memory");
	return ret;
}
#endif

#define EEXIST       17

#define CLONE_FS            0x00000200
#define CLONE_FILES         0x00000400
#define CLONE_NEWNS         0x00020000
#define CLONE_SYSVSEM       0x00040000
#define CLONE_NEWCGROUP     0x02000000
#define CLONE_NEWUTS        0x04000000
#define CLONE_NEWIPC        0x08000000
#define CLONE_NEWUSER       0x10000000
#define CLONE_NEWPID        0x20000000
#define CLONE_NEWNET        0x40000000
#define CLONE_NEWTIME       0x00000080

#define MS_RDONLY    1
#define MS_NOSUID    2
#define MS_NODEV     4
#define MS_NOEXEC    8
#define MS_BIND		4096
#define MS_REC		16384
#define MS_SILENT	32768

#define MS_UNBINDABLE	(1<<17)
#define MS_PRIVATE	(1<<18)
#define MS_SLAVE	(1<<19)
#define MS_SHARED	(1<<20)

#define MNT_DETACH  2

#define O_RDONLY  0000
#define O_WRONLY  0001
#define O_CREAT   0100
#define O_EXCL    0200

#define FSCONFIG_CMD_CREATE   6

struct ifmap {
	/* copied from musl libc */
	unsigned long int mem_start;
	unsigned long int mem_end;
	unsigned short int base_addr;
	unsigned char irq;
	unsigned char dma;
	unsigned char port;
};

struct ifreq {
	char ifr_name[IFNAMSIZ+1];
	union {
		int ifr_ifindex;
	};
};


static inline ssize_t write(int fd, const char *data, size_t n) {
	return syscall3(SYS_WRITE, fd, (size_t)data, n);
}
static inline int open(const char *path, int flags, int perm) {
	return syscall3(SYS_OPEN, (size_t)path, flags, perm);
}
static inline int close(int fd) {
	return syscall1(SYS_CLOSE, fd);
}
static inline int socket(int domain, int type, int protocol) {
	return syscall3(SYS_SOCKET, domain, type, protocol);
}
static inline int bind(int fd, const struct sockaddr *addr, socklen_t addrlen) {
	return syscall3(SYS_BIND, fd, (size_t)addr, addrlen);
}
static inline int sendmsg(int fd, const struct msghdr *msg, int flags) {
	return syscall3(SYS_SENDMSG, fd, (size_t)msg, flags);
}
static inline int recvmsg(int fd, struct msghdr *msg, int flags) {
	return syscall3(SYS_RECVMSG, fd, (size_t)msg, flags);
}
static inline pid_t getpid(void) {
	return syscall0(SYS_GETPID);
}
static inline uid_t getuid(void) {
	return syscall0(SYS_GETUID);
}
static inline gid_t getgid(void) {
	return syscall0(SYS_GETGID);
}
static inline ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count) {
	return syscall4(SYS_SENDFILE, out_fd, in_fd, (size_t)offset, count);
}
static inline int fork(void) {
	return syscall0(SYS_FORK);
}
static inline int prctl1(int option, size_t a0) {
	return syscall2(SYS_PRCTL, option, a0);
}
static inline int prctl2(int option, size_t a0, size_t a1) {
	return syscall3(SYS_PRCTL, option, a0, a1);
}
static inline int prctl3(int option, size_t a0, size_t a1, size_t a2) {
	return syscall4(SYS_PRCTL, option, a0, a1, a2);
}
static inline int prctl4(int option, size_t a0, size_t a1, size_t a2, size_t a3) {
	return syscall5(SYS_PRCTL, option, a0, a1, a2, a3);
}
_Noreturn static inline void exit(int status) {
	syscall1(SYS_EXIT, status);
	__builtin_unreachable();
}
static inline int setsid(void) {
	return syscall0(SYS_SETSID);
}
static inline int chroot(const char *path) {
	return syscall1(SYS_CHROOT, (size_t)path);
}
static inline int getsockname(int fd, struct sockaddr *addr, socklen_t *optlen) {
	return syscall3(SYS_GETSOCKNAME, fd, (size_t)addr, (size_t)optlen);
}
static inline int setsockopt(int fd, int level, int optname, void *optval, socklen_t optlen) {
	return syscall5(SYS_SETSOCKOPT, fd, level, optname, (size_t)optval, optlen);
}
static inline int getsockopt(int fd, int level, int optname, void *optval, socklen_t *optlen) {
	return syscall5(SYS_GETSOCKOPT, fd, level, optname, (size_t)optval, (size_t)optlen);
}
static inline int clone(int fn(void*), void *stack, int flags, void *arg) {
	return syscall4(SYS_CLONE, (size_t)fn, (size_t)stack, flags, (size_t)arg);
}
static inline int execve(const char *path, char *const *argv, char *const *envp) {
	return syscall3(SYS_EXECVE, (size_t)path, (size_t)argv, (size_t)envp);
}
static inline int wait4(int pid, int *wstatus, int options, struct rusage *rusage) {
	return syscall4(SYS_WAIT4, pid, (size_t)wstatus, options, (size_t)rusage);
}
static inline int chdir(const char *path) {
	return syscall1(SYS_CHDIR, (size_t)path);
}
static inline int mkdir(const char *path, int mode) {
	return syscall2(SYS_MKDIR, (size_t)path, mode);
}
static inline int pivot_root(const char *new_root, const char *put_old) {
	return syscall2(SYS_PIVOT_ROOT, (size_t)new_root, (size_t)put_old);
}
static inline int mount
	( const char *source
	, const char *target
	, const char *filesystemtype
	, unsigned long mountflags
	, const void *data
	) {
	return syscall5
		( SYS_MOUNT
		, (size_t)source
		, (size_t)target
		, (size_t)filesystemtype
		, mountflags
		, (size_t)data
		);
}
static inline int umount2(const char *target, int flags) {
	return syscall2(SYS_UMOUNT2, (size_t)target, flags);
}
static inline int unshare(int flags) {
	return syscall1(SYS_UNSHARE, flags);
}
static inline int fsopen(const char *fsname, unsigned int flags) {
	return syscall2(SYS_FSOPEN, (size_t)fsname, flags);
}
static inline int fsconfig(int fd, unsigned int cmd, const char *key, const void *value, int aux) {
	return syscall5(SYS_FSCONFIG, fd, cmd, (size_t)key, (size_t)value, aux);
}
static inline int fsmount(int fsfd, unsigned int flags, unsigned int attr_flags) {
	return syscall3(SYS_FSMOUNT, fsfd, flags, attr_flags);
}
static inline ssize_t getrandom(void *buf, size_t size, int flags) {
	return syscall3(SYS_GETRANDOM, (size_t)buf, size, flags);
}
/* behold the most fucked interface on the planet */
/* I will not attempt to replicate it accurately  */
static inline int ioctl(int fd, int request, size_t arg) {
	return syscall3(SYS_IOCTL, fd, request, arg);
}
static inline time_t time(time_t *t) {
	return syscall1(SYS_TIME, (size_t)t);
}

static inline size_t strlen(const char *s) {
	const char *e = s;

	while (*e)
		e++;
	return e - s;
}

static inline void *memcpy(void *dst, const void *src, size_t n) {
	char *d = dst, *e = d + n;
	const char *s = src;

	while (d != e)
		*d++ = *s++;
	return dst;
}

static inline void *memset(void *dst, int c, size_t n) {
	char *d = dst, *e = d + n;
	while (d != e)
		*d++ = c;
	return dst;
}

static inline int strcmp(const char *x, const char *y) {
	while (*x && *y && *x == *y)
		x++, y++;
	return (int)*x - (int)*y;
}

static inline void *strcpy(char *dst, const char *src) {
	return memcpy(dst, src, strlen(src) + 1);
}

static inline void *strncpy(char *dst, const char *src, size_t n) {
	size_t x;

	x = strlen(src);
	return memcpy(dst, src, x < n ? x : n);
}

static inline void *strcat(char *dst, const char *src) {
	return strcpy(dst + strlen(dst), src);
}

static inline u32 htobe32(u32 x) {
	return (x << 24) | ((x << 16) & 0xff0000) | ((x << 8) & 0xff00) | (x & 0xff);
}
