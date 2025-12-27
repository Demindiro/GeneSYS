#!/bin/sh
set -xe
qemu-system-x86_64 -drive file=/tmp/lemmings-legacy-vmboot.img,format=raw
