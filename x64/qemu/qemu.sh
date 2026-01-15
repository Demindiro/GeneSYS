#!/bin/sh
set -xe
exec qemu-system-x86_64 \
	-drive file=build/qemu/root.img,if=virtio,format=raw \
	-serial unix:/tmp/genesys.unix,server,nowait \
	"$@"
