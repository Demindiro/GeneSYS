#pragma once

#include "util.h"

static void nlmsg_append(struct nlmsghdr *msg, const void *data, size_t n) {
	memcpy((char*)msg + msg->nlmsg_len, data, n);
	msg->nlmsg_len += n;
}
static void nlmsg_pad4(struct nlmsghdr *msg) {
	while ((msg->nlmsg_len & 3) != 0)
		((char*)msg)[msg->nlmsg_len++] = 0;
}

static size_t  nla_start(struct nlmsghdr *msg, u16 type) {
	struct nlattr x;
	size_t offset;

	offset = msg->nlmsg_len;
	x.nla_len = -1;
	x.nla_type = type;
	nlmsg_append(msg, &x, sizeof x);
	return offset;
}
static void nla_end(struct nlmsghdr *msg, size_t offset) {
	((struct nlattr *)((char *)msg + offset))->nla_len = msg->nlmsg_len - offset;
	nlmsg_pad4(msg);
}
static void nla_append_one(struct nlmsghdr *msg, u16 type, const void *data, size_t n) {
	size_t x;

	x = nla_start(msg, type);
	nlmsg_append(msg, data, n);
	nla_end(msg, x);
}

static int netlink_connect(void) {
	struct sockaddr_nl addr;
	int fd;

	fd = socket(AF_NETLINK, SOCK_RAW | SOCK_CLOEXEC, NETLINK_ROUTE);
	if (fd < 0)
		die("socket AF_NETLINK, NETLINK_ROUTE");
	addr.nl_family = AF_NETLINK;
	addr.nl_pid = 0;
	addr.nl_groups = 0;
	if (bind(fd, (const struct sockaddr *)&addr, sizeof addr) < 0)
		die("bind AF_NETLINK");
	return fd;
}

static void netlink_send(int fd, const struct nlmsghdr *nlmsg) {
	struct sockaddr_nl addr;
	struct iovec iov;
	struct msghdr msg;
	ssize_t ret;

	addr.nl_family = AF_NETLINK;
	addr.nl_pid = 0;
	addr.nl_groups = 0;
	iov.iov_base = (void *)nlmsg;
	iov.iov_len  = nlmsg->nlmsg_len;
	msg.msg_name = &addr;
	msg.msg_namelen = sizeof addr;
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;
	msg.msg_controllen = 0;
	msg.msg_flags = 0;
	ret = sendmsg(fd, &msg, 0);
	if (ret < 0)
		die("sendmsg");
}

static void netlink_recv(int fd, struct nlmsghdr *nlmsg, size_t nlmsg_len) {
	struct sockaddr_nl addr;
	struct iovec iov;
	struct msghdr msg;
	ssize_t ret;

	iov.iov_base = nlmsg;
	iov.iov_len  = nlmsg_len;
	msg.msg_name = &addr;
	msg.msg_namelen = sizeof addr;
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;
	msg.msg_controllen = 0;
	msg.msg_flags = 0;
	ret = recvmsg(fd, &msg, 0);
	if (ret < 0)
		die("recvmsg");
}

static u32 rtm_link_index(int fd, const char *ifname) {
	struct {
		struct nlmsghdr   hdr;
		char              data[20000];
	} nlmsg;
	struct ifinfomsg ifi;

	nlmsg.hdr.nlmsg_len = sizeof(nlmsg.hdr);
	nlmsg.hdr.nlmsg_type = RTM_GETLINK;
	nlmsg.hdr.nlmsg_flags = NLM_F_REQUEST;
	nlmsg.hdr.nlmsg_seq = 0;
	nlmsg.hdr.nlmsg_pid = 0;

	ifi.ifi_family = AF_PACKET;
	ifi.ifi_type   = 0;
	ifi.ifi_index  = 0;
	ifi.ifi_flags  = 0;
	ifi.ifi_change = 0;
	nlmsg_append(&nlmsg.hdr, &ifi, sizeof ifi);

	nla_append_one(&nlmsg.hdr, IFLA_IFNAME, ifname, strlen(ifname) + 1);

	netlink_send(fd, &nlmsg.hdr);
	netlink_recv(fd, &nlmsg.hdr, sizeof nlmsg);

	if (nlmsg.hdr.nlmsg_type == NLMSG_ERROR)
		return 0;
	if (nlmsg.hdr.nlmsg_type != RTM_NEWLINK)
		die("rtm_link_index expected RTM_NEWLINK");

	memcpy(&ifi, nlmsg.data, sizeof ifi);
	return ifi.ifi_index;
}

static void rtm_link_up(int fd, u32 index) {
	struct {
		struct nlmsghdr   hdr;
		char              data[200];
	} nlmsg;
	struct ifinfomsg ifi;

	nlmsg.hdr.nlmsg_len = sizeof(nlmsg.hdr);
	nlmsg.hdr.nlmsg_type = RTM_SETLINK;
	nlmsg.hdr.nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	nlmsg.hdr.nlmsg_seq = 0;
	nlmsg.hdr.nlmsg_pid = 0;

	ifi.ifi_family = 0;
	ifi.ifi_type   = 0;
	ifi.ifi_index  = index;
	ifi.ifi_flags  = IFF_UP;
	ifi.ifi_change = IFF_UP;
	nlmsg_append(&nlmsg.hdr, &ifi, sizeof ifi);

	netlink_send(fd, &nlmsg.hdr);
	netlink_recv(fd, &nlmsg.hdr, sizeof nlmsg);
}
