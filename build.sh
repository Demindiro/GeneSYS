#!/bin/sh
out=build
set -xe
mkdir -p $out
fasm bootloader.asm $out/bootloader.bin
fasm mbr.asm $out/root.img
