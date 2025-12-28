#!/bin/sh
set -xe
exec qemu-system-x86_64 -drive file=build/root.img,if=virtio,format=raw "$@"
exec qemu-system-x86_64 -M q35 -drive file=build/root.img,format=raw "$@"
exec qemu-system-x86_64 -M q35 -drive file=build/root.img,if=none,format=raw,id=root -device virtio-blk-pci,drive=root,bootindex=1 "$@"
exec qemu-system-x86_64 -drive file=build/root.img,if=none,format=raw,id=root -device virtio-blk-pci,drive=root,bootindex=1 "$@"
exec qemu-system-x86_64 -drive file=build/root.img,if=virtio,boot=on,format=raw "$@"
exec qemu-system-x86_64 -drive file=build/root.img,if=none,id=virtio-disk0,format=raw -device virtio-blk-pci,drive=virtio-disk0,id=disk0 "$@"
exec qemu-system-x86_64 -drive file=build/root.img,format=raw "$@"
