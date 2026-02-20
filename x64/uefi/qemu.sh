#!/bin/sh

QEMU="${QEMU:-qemu-system-x86_64}"

set -xe
exec "$QEMU" \
	-machine q35 \
	-cpu max \
	-bios "$UEFI_BIOS" \
	-device amd-iommu \
	-drive file=build/uefi/root.img,if=virtio,format=raw \
	-serial unix:/tmp/genesys.unix \
	"$@"
