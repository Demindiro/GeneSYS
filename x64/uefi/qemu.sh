#!/bin/sh
set -xe
exec qemu-system-x86_64 \
	-machine q35 \
	-cpu max \
	-bios "$UEFI_BIOS" \
	-drive file=build/uefi/root.img,if=virtio,format=raw \
	-serial unix:/tmp/genesys.unix,server,nowait \
	"$@"
