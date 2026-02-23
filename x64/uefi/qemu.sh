#!/bin/sh

QEMU="${QEMU:-qemu-system-x86_64}"

set -xe
exec $QEMUWRAP "$QEMU" \
	-machine q35 \
	-cpu max \
	-bios "$UEFI_BIOS" \
	-device amd-iommu \
	-device edu \
	-drive file=build/uefi/root.img,if=virtio,format=raw \
	-serial unix:/tmp/genesys.unix \
	"$@"
