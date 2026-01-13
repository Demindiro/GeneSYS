#!/bin/sh
set -xe
export out=./build/$1
mkdir -p $out
exec sh x64/$1/build.sh
