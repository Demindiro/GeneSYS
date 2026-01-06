#!/bin/sh
set -xe
exec qemu-system-x86_64 \
	-machine q35 \
	-bios "$UEFI_BIOS" \
	-drive file=build/uefi/root.img,if=virtio,format=raw \
	"$@"
