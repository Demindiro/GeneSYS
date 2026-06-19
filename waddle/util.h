#pragma once

#include "sys.h"

static inline int streq(const char *x, const char *y) {
	return strcmp(x, y) == 0;
}

static inline int str_startswith(const char *s, const char *prefix) {
	while (*prefix) {
		if (*s != *prefix)
			return 0;
		s++, prefix++;
	}
	return 1;
}

static inline int write_str(int fd, const char *s) {
	return write(fd, s, strlen(s));
}

static inline int write_file_str(const char *path, const char *s) {
	int ret, fd;

	fd = open(path, O_WRONLY, 0);
	if (fd < 0)
		return -1;
	ret = write_str(fd, s);
	close(fd);
	return ret;
}

_Noreturn static void die(const char *msg) {
	write_str(2, msg);
	write_str(2, " failed\n");
	exit(1);
}

static inline void safe_strcat(char *buf, size_t buflen, const char *src) {
	size_t x, y;

	x = strlen(buf);
	y = strlen(src);
	if (buflen - x < y + 1)
		die("safe_strcat");
	memcpy(buf + x, src, y + 1);
}

static inline u16 parse_u16(const char *s) {
	u32 x = 0;
	char c;

	do {
		c = *s;
		if (c == 0)
			die("parse_u16 empty str");
		s++;
		if (c < '0' || '9' < c)
			die("parse_u16 invalid digit");
		x = (x * 10) + (c - '0');
		if (x >= (1U << 16))
			die("parse_u16 overflow");
	} while (*s);
	return x;
}

static inline char *fmt_u64(char buf[32], u64 x) {
	char *p;

	p = buf + 32;
	*--p = 0;
	do {
		*--p = '0' + (x % 10);
		x /= 10;
	} while (x);
	return p;
}
