#!/bin/sh
src="$(dirname "$0")"
set -xe
mkdir -p $out/

fasm $src/../common/boot.asm $out/kernel.bin
fasm $src/boot.asm $out/bootx64.efi


# https://wiki.osdev.org/User:Demindiro/Super_Tiny_UEFI_Hello_World

fat=$out/efi-fs.img
gpt=$out/root.img
fallocate -l512K $fat
mformat -i $fat
mmd     -i $fat             ::/efi ::/efi/boot
mcopy   -i $fat $out/bootx64.efi ::/efi/boot/bootx64.efi
mdir    -i $fat -/ -w -a

fallocate -l1M $gpt
cat <<CMD | fdisk $gpt
g
n



t
uefi
w
CMD
fdisk -l $gpt

dd if=$fat of=$gpt bs=512 oseek=34 conv=notrunc

fdisk -l $gpt
