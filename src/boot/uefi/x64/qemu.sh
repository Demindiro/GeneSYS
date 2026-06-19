#!/bin/sh

QEMU="${QEMU:-qemu-system-x86_64}"
ROOT="${ROOT:-build/out/uefi/root.img}"

set -xe
exec $QEMUWRAP "$QEMU" \
	-machine q35 \
	-cpu max \
	-bios "$UEFI_BIOS" \
	-device intel-iommu,x-scalable-mode=on,x-flts=on \
	-device edu,dma_mask=0xffffffffffffffff \
	-drive file="$ROOT",if=virtio,format=raw \
	-serial unix:/tmp/genesys.unix \
	"$@"

	-device amd-iommu,device-iotlb=on,dma-remap=on,dma-translation=on \
