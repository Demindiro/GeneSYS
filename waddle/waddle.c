#include "sys.h"
#include "util.h"
#include "netlink.h"

#define PROGNAME         "waddle"
#define PREP_DIR         "/tmp/waddle-newns"
#define MAX_BIND_MOUNTS  100

struct bind_mount {
	char *source;
	char *target;
};

struct config {
	struct bind_mount bind_mounts[MAX_BIND_MOUNTS];
	char *base_dir;
	char *overlay_dir;
	char *overlay_workdir;
	char **child_argv;
	char *uid;
	char *gid;
	char *cwd;
	int child_argc;
	int num_bind_mounts;
	int flags;
};

#define CONFIG_FLAG_MOUNT_PROC   (1 << 0)
#define CONFIG_FLAG_NET          (1 << 1)
#define CONFIG_FLAG_NO_INIT      (1 << 2)

static int wait_all_descendants(void) {
	while (wait4(-1, NULL, 0, NULL) >= 0)
		/* pass */;
	return 0;
}

static int run_as_init(void) {
	prctl4(PR_SET_PDEATHSIG, SIGKILL, 0, 0, 0);
	return wait_all_descendants();
}

static void usage(const char *progname, int is_err) {
	int fd;

	fd = is_err ? 2 : 1;
	progname = progname ? progname : PROGNAME;
	write_str(fd, "usage: ");
	write_str(fd, progname);
	write_str(fd, " --base <target> [options] -- <bin> [args...]\n"
		"  --help                     this help text\n"
		"  --base <source>[:...]      use directory as root\n"
		"                             multiple directories can be specified,\n"
		"                             separated by a double colon\n"
		"  --overlay <source> <work>  overlay directory over root\n"
		"                             <work> must be a directory on the\n"
		"                             same filesystem\n"
		"  --bind <target> <source>   bind an arbitrary directory\n"
		"  --mount-proc               mount proc on /proc\n"
		"  --net                      allow network access\n"
		"  --uid <uid>                set mapped UID (default 0, max 65535)\n"
		"  --gid <gid>                set mapped GID (default 0, max 65535)\n"
		"  --cwd <dir>                change work directory before running command\n"
		"  --no-init                  do not spawn an init process\n"
	);
	exit(is_err ? 1 : 0);
}

static int parse_argc(int argc, char **argv, struct config *conf) {
	char **end, *a, *progname;

	end = argv + argc;
	progname = *argv++;
	memset(conf, 0, sizeof(conf));
	conf->uid = "0";
	conf->gid = "0";
	while (argv != end) {
		a = *argv++;
		if (streq(a, "--")) {
			break;
		}
		if (streq(a, "-h") || streq(a, "--help")) {
			usage(progname, 0);
		}
		if (streq(a, "--bind")) {
			if (conf->num_bind_mounts >= MAX_BIND_MOUNTS)
				die("too many --bind");
			if (end - argv < 2)
				die("--bind <target> <source>");
			conf->bind_mounts[conf->num_bind_mounts].target = *argv++;
			conf->bind_mounts[conf->num_bind_mounts].source = *argv++;
			conf->num_bind_mounts++;
		} else if (streq(a, "--net")) {
			conf->flags |= CONFIG_FLAG_NET;
		} else if (streq(a, "--mount-proc")) {
			conf->flags |= CONFIG_FLAG_MOUNT_PROC;
		} else if (streq(a, "--no-init")) {
			conf->flags |= CONFIG_FLAG_NO_INIT;
		} else if (streq(a, "--base")) {
			if (end - argv < 1)
				die("--base <dir>");
			if (conf->base_dir)
				die("--base already specified");
			conf->base_dir = *argv++;
		} else if (streq(a, "--overlay")) {
			if (end - argv < 2)
				die("--overlay <dir> <workdir>");
			if (conf->overlay_dir)
				die("--overlay already specified");
			conf->overlay_dir = *argv++;
			conf->overlay_workdir = *argv++;
		} else if (streq(a, "--uid")) {
			if (end - argv < 1)
				die("--uid <num>");
			/* validate but don't use the result,
			 * since we need a string anyway */
			parse_u16(*argv);
			conf->uid = *argv++;
		} else if (streq(a, "--gid")) {
			if (end - argv < 1)
				die("--gid <num>");
			/* ditto */
			parse_u16(*argv);
			conf->gid = *argv++;
		} else if (streq(a, "--cwd")) {
			if (end - argv < 1)
				die("--cwd <dir>");
			conf->cwd = *argv++;
		} else {
			usage(progname, 1);
		}
	}
	conf->child_argv = argv;
	conf->child_argc = end - argv;
	return 0;
}

static void mkdir_rec(const char *path) {
	int ret;
	size_t i;
	char buf[4096], c;

	if (path[0] == 0)
		return;
	i = 1;
	strcpy(buf, path);
	while (1) {
		c = buf[i];
		if (c == '/' || c == 0) {
			buf[i] = 0;
			ret = mkdir(buf, 0700);
			if (ret < 0 && ret != -EEXIST) {
				strcpy(buf, "mkdir_rec");
				safe_strcat(buf, sizeof buf, path);
				die(buf);
			}
			if (c == 0)
				break;
			buf[i] = c;
		}
		i++;
	}
}

static void apply_bind_mounts(const struct config *conf) {
	const struct bind_mount *x, *end;
	char target[4096];

	x = conf->bind_mounts;
	end = x + conf->num_bind_mounts;
	while (x != end) {
		strcpy(target, PREP_DIR);
		safe_strcat(target, sizeof target, x->target);
		mkdir_rec(target);
		if (mount(x->source, target, "", MS_BIND|MS_REC, NULL) < 0)
			die("bind mount");
		x++;
	}
}

static void write_proc_self_id_map(const char *path, const char *target_id, u32 source_id) {
	char buf[64], fmt_buf[32];

	strcpy(buf, target_id);
	safe_strcat(buf, sizeof buf, " ");
	safe_strcat(buf, sizeof buf, fmt_u64(fmt_buf, source_id));
	safe_strcat(buf, sizeof buf, " 1");
	if (write_file_str(path, buf) < 0) {
		strcpy(buf, "write ");
		safe_strcat(buf, sizeof buf, path);
		die(buf);
	}
}

static void set_loopback_up(void) {
	int fd;
	u32 index;

	fd = netlink_connect();
	index = rtm_link_index(fd, "lo");
	rtm_link_up(fd, index);
}

static void exec_path(char *exe, char **argv, char **environ) {
	char buf[4096];
	char *path, *npath, **env;

	/* unsure about the exact rules, but it appears to be:
	 * - preceded by /, ./ or ../ : exec immediately
	 * - otherwise, scan path
	 */
	if (str_startswith(exe, "/")
			|| str_startswith(exe, "./")
			|| str_startswith(exe, "../"))
	{
		execve(exe, argv, environ);
		return;
	}
	path = "";
	env = environ;
	while (*env) {
		if (str_startswith(*env, "PATH=")) {
			path = *env + 5;
			break;
		}
		env++;
	}
	while (*path) {
		npath = path;
		while (*npath && *npath != ':')
			npath++;
		if ((size_t)(npath - path) >= sizeof buf)
			die("PATH segment too long");
		memcpy(buf, path, npath - path);
		buf[npath - path] = 0;
		safe_strcat(buf, sizeof buf, "/");
		safe_strcat(buf, sizeof buf, exe);
		execve(buf, argv, environ);
		if (!*npath)
			break;
		path = npath + 1;
	}
}

int main(int argc, char **argv, char **environ) {
	struct config conf;
	int ret;
	char buf[4096];
	uid_t uid;
	gid_t gid;

	if (parse_argc(argc, argv, &conf) < 0)
		return 1;
	if (!conf.base_dir || conf.child_argc < 1)
		usage(*argv, 1);

	uid = getuid();
	gid = getgid();

	ret = unshare
		( CLONE_FS
		| CLONE_FILES
		| CLONE_NEWCGROUP
		| CLONE_NEWIPC
		| CLONE_NEWNS
		| CLONE_NEWPID
		| CLONE_NEWTIME
		| CLONE_NEWUSER
		| CLONE_NEWUTS
		| CLONE_SYSVSEM
		| (conf.flags & CONFIG_FLAG_NET ? 0 : CLONE_NEWNET)
		);

	if (ret < 0)
		die("unshare");

	/* necessary to write gid_map
	 * https://unix.stackexchange.com/a/692194
	 */
	if (write_file_str("/proc/self/setgroups", "deny") < 0)
		die("write /proc/self/setgroups");

	write_proc_self_id_map("/proc/self/uid_map", conf.uid, uid);
	write_proc_self_id_map("/proc/self/gid_map", conf.gid, gid);

	mkdir_rec(PREP_DIR);

	if (conf.overlay_dir) {
		mkdir_rec(conf.overlay_dir);
		mkdir_rec(conf.overlay_workdir);
		strcpy(buf, "lowerdir=");
		safe_strcat(buf, sizeof buf, conf.base_dir);
		safe_strcat(buf, sizeof buf, ",upperdir=");
		safe_strcat(buf, sizeof buf, conf.overlay_dir);
		safe_strcat(buf, sizeof buf, ",workdir=");
		safe_strcat(buf, sizeof buf, conf.overlay_workdir);
		if (mount("", PREP_DIR, "overlay", 0, buf) < 0)
			die("mount overlay");
	} else {
		if (mount(conf.base_dir, PREP_DIR, "", MS_BIND|MS_REC, NULL) < 0)
			die("mount base");
	}

	apply_bind_mounts(&conf);

	mkdir_rec(PREP_DIR "/root");

	/* fork to enter new PID namespace properly
	 * also necessary to be able to mount the super-ultra-turbo-magic proc FS
	 */
	ret = fork();
	if (ret < 0)
		die("fork PID");
	if (ret != 0)
		return wait_all_descendants();
	setsid(); /* ignore errors */

	if (!(conf.flags & CONFIG_FLAG_NO_INIT)) {
		ret = fork();
		if (ret < 0)
			die("fork init");
		if (ret != 0)
			return run_as_init();
		setsid();
	}

	if (pivot_root(PREP_DIR, PREP_DIR "/root") < 0)
		die("pivot_root");
	if (chdir("/") < 0)
		die("chdir /");

	/* do not fucking change the location of this code
	 * change it just a bit and EPERM EPERM EPERM EPERM
	 * I'm losing my goddamn mind
	 */
	if (conf.flags & CONFIG_FLAG_MOUNT_PROC) {
		mkdir_rec("/proc");
		if (mount("proc", "/proc", "proc", MS_NOSUID|MS_NODEV|MS_NOEXEC, NULL) < 0)
			die("mount /proc");
	}

	if (umount2("/root", MNT_DETACH) < 0)
		die("umount /root");

	/* chdir to user directory after umounting root to avoid confusion
	 * and accidental escapes */
	if (conf.cwd && chdir(conf.cwd) < 0) {
		strcpy(buf, "chdir ");
		safe_strcat(buf, sizeof buf, conf.cwd);
		die(buf);
	}

	if (!(conf.flags & CONFIG_FLAG_NET)) {
		set_loopback_up();
	}

	exec_path(conf.child_argv[0], conf.child_argv, environ);
	die("exec_path");
}
