#!/bin/sh
set -xe
export out=./build
exec sh x64/bios/build.sh
