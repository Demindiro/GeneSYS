#!/bin/sh
src="$(dirname "$0")"
set -xe
mkdir -p $out/root
fasm $src/bootloader.asm $out/kernel
fasm $src/init/hello.asm $out/init
echo "Hello, world! This is an auxiliary file" > $out/aux
fasm $src/gsboot.asm $out/root.gsboot
fasm $src/mbr.asm $out/root.img
