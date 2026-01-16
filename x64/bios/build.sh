#!/bin/sh
src="$(dirname "$0")"
set -xe
mkdir -p $out/root
fasm $src/../common/kernel.asm $out/kernel.bin
fasm $src/vbr.asm $out/vbr.img
fasm $src/mbr.asm $out/root.img
