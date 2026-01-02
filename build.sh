#!/bin/sh
out=./build
set -xe
mkdir -p $out/root
fasm bootloader.asm $out/kernel
fasm init/hello.asm $out/init
echo "Hello, world! This is an auxiliary file" > $out/aux
fasm gsboot.asm $out/root.gsboot
fasm mbr.asm $out/root.img
