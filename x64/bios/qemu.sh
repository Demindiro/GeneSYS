#!/bin/sh
set -xe
exec qemu-system-x86_64 \
	-drive file=build/bios/root.img,if=virtio,format=raw \
	"$@"
