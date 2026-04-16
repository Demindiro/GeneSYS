#!/bin/sh

QEMU="${QEMU:-qemu-system-x86_64}"
ROOT="${ROOT:-build/uefi/root.img}"

set -xe
exec $QEMUWRAP "$QEMU" \
	-machine q35 \
	-cpu max \
	-bios "$UEFI_BIOS" \
	-device amd-iommu,device-iotlb=on,dma-remap=on,dma-translation=on \
	-device edu,dma_mask=0xffffffffffffffff \
	-drive file="$ROOT",if=virtio,format=raw \
	-serial unix:/tmp/genesys.unix \
	"$@"
